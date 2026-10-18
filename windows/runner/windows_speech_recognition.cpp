#include "windows_speech_recognition.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Media.SpeechRecognition.h>

#include <atomic>
#include <chrono>
#include <deque>
#include <iostream>
#include <mutex>
#include <thread>

namespace {
using namespace winrt::Windows::Media::SpeechRecognition;
using winrt::Windows::Foundation::IAsyncInfo;
using winrt::Windows::Globalization::Language;
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
using Reply = std::unique_ptr<flutter::MethodResult<Value>>;

struct SpeechEvent {
  std::string type;
  std::string text;
  std::string error;
};

struct SpeechSession {
  HWND window;
  UINT message;
  std::atomic<bool> canceled{false};
  std::mutex mutex;
  std::deque<SpeechEvent> events;
  IAsyncInfo operation{nullptr};

  void Emit(SpeechEvent event) {
    {
      std::lock_guard<std::mutex> lock(mutex);
      events.push_back(std::move(event));
    }
    ::PostMessageW(window, message, 0, 0);
  }

  void Cancel() {
    if (canceled.exchange(true)) return;
    IAsyncInfo pending{nullptr};
    {
      std::lock_guard<std::mutex> lock(mutex);
      pending = operation;
    }
    if (pending) {
      // Cancellation can cross a process boundary; never block the window thread.
      std::thread([pending = std::move(pending)]() mutable {
        bool apartment_initialized = false;
        try {
          winrt::init_apartment(winrt::apartment_type::multi_threaded);
          apartment_initialized = true;
          pending.Cancel();
        } catch (const winrt::hresult_error& error) {
          ::OutputDebugStringW(error.message().c_str());
        }
        pending = nullptr;
        if (apartment_initialized) winrt::uninit_apartment();
      }).detach();
    }
  }

  void Track(const IAsyncInfo& pending) {
    {
      std::lock_guard<std::mutex> lock(mutex);
      operation = pending;
    }
    // Covers cancellation between starting an operation and publishing it.
    if (canceled) pending.Cancel();
  }
};

Language ResolveLanguage(const std::string& requested) {
  // Match Electron's UI-locale to speech-locale mapping before OS lookup.
  const std::pair<const char*, const char*> locales[] = {
      {"zh-Hant", "zh-TW"}, {"fr", "fr-FR"}, {"ru", "ru-RU"},
      {"ja", "ja-JP"}, {"de", "de-DE"}, {"es", "es-ES"},
      {"it", "it-IT"}, {"nl", "nl-NL"}, {"cs", "cs-CZ"},
      {"uk", "uk-UA"}, {"sv", "sv-SE"}, {"id", "id-ID"},
  };
  auto speech_locale = requested;
  for (const auto& locale : locales) {
    if (requested == locale.first) {
      speech_locale = locale.second;
      break;
    }
  }
  const Language language(winrt::to_hstring(speech_locale));
  const auto supported = SpeechRecognizer::SupportedTopicLanguages();
  for (const auto& item : supported) {
    if (item.LanguageTag() == language.LanguageTag()) return item;
  }
  const auto tag = winrt::to_string(language.LanguageTag());
  const auto primary = tag.substr(0, tag.find('-'));
  for (const auto& item : supported) {
    const auto item_tag = winrt::to_string(item.LanguageTag());
    if (item_tag.substr(0, item_tag.find('-')) == primary &&
        (primary != "zh" || item.Script() == language.Script())) {
      return item;
    }
  }
  if (primary == "zh") {
    throw winrt::hresult_error(HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED));
  }
  return SpeechRecognizer::SystemSpeechLanguage();
}

void Recognize(const std::shared_ptr<SpeechSession>& session,
               const std::string& language) {
  SpeechRecognizer recognizer{nullptr};
  bool apartment_initialized = false;
  SpeechEvent completed{"result", "", ""};
#ifdef _DEBUG
  const auto started = std::chrono::steady_clock::now();
#endif
  try {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    apartment_initialized = true;
    recognizer = SpeechRecognizer(ResolveLanguage(language));
#ifdef _DEBUG
    std::cerr << "WinRT speech language: "
              << winrt::to_string(recognizer.CurrentLanguage().LanguageTag())
              << std::endl;
    recognizer.RecognitionQualityDegrading([](auto&&, auto&& args) {
      std::cerr << "WinRT speech audio problem: "
                << static_cast<int>(args.Problem()) << std::endl;
    });
#endif
    recognizer.UIOptions().IsReadBackEnabled(false);
    recognizer.HypothesisGenerated([session](auto&&, auto&& args) {
      session->Emit({"hypothesis", winrt::to_string(args.Hypothesis().Text()), ""});
    });
    recognizer.StateChanged([session](auto&&, auto&& args) {
#ifdef _DEBUG
      std::cerr << "WinRT speech state: " << static_cast<int>(args.State())
                << std::endl;
#endif
      std::string state = "Idle";
      switch (args.State()) {
        case SpeechRecognizerState::Capturing: state = "Capturing"; break;
        case SpeechRecognizerState::SoundStarted: state = "SoundStarted"; break;
        case SpeechRecognizerState::SpeechDetected: state = "SpeechDetected"; break;
        case SpeechRecognizerState::Processing: state = "Processing"; break;
        default: break;
      }
      session->Emit({"state", state, ""});
    });
    const auto compilation = recognizer.CompileConstraintsAsync();
    session->Track(compilation);
    const auto compiled = compilation.get();
    if (compiled.Status() != SpeechRecognitionResultStatus::Success) {
      completed.error = "unavailable";
    } else if (!session->canceled) {
      session->Emit({"state", "Ready", ""});
      // Match Electron's recognition entry point and disabled read-back.
      const auto operation = recognizer.RecognizeWithUIAsync();
      session->Track(operation);
      const auto result = operation.get();
#ifdef _DEBUG
      std::cerr << "WinRT speech result status: "
                << static_cast<int>(result.Status())
                << "; characters: " << result.Text().size()
                << "; confidence: " << static_cast<int>(result.Confidence())
                << "; raw confidence: " << result.RawConfidence()
                << "; elapsed ms: "
                << std::chrono::duration_cast<std::chrono::milliseconds>(
                       std::chrono::steady_clock::now() - started).count()
                << std::endl;
#endif
      if (result.Status() == SpeechRecognitionResultStatus::Success) {
        completed.text = winrt::to_string(result.Text());
        if (completed.text.empty()) completed.error = "no-speech";
      } else if (result.Status() == SpeechRecognitionResultStatus::UserCanceled) {
        completed.error = "canceled";
      } else if (result.Status() == SpeechRecognitionResultStatus::TimeoutExceeded) {
        completed.error = "no-speech";
      } else if (result.Status() == SpeechRecognitionResultStatus::MicrophoneUnavailable ||
                 result.Status() == SpeechRecognitionResultStatus::AudioQualityFailure) {
        completed.error = "audio-capture";
      } else {
        completed.error = "failed";
      }
    }
  } catch (const winrt::hresult_error& error) {
#ifdef _DEBUG
    std::cerr << "WinRT speech error: " << std::hex
              << static_cast<uint32_t>(error.code().value) << " "
              << winrt::to_string(error.message()) << std::dec << std::endl;
#endif
    const auto diagnostic = std::wstring(L"SMPlayer speech: ") +
                            error.message().c_str() + L"\n";
    ::OutputDebugStringW(diagnostic.c_str());
    if (error.code() == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
      completed.error = "canceled";
    } else {
      completed.error = error.code() == E_ACCESSDENIED ? "privacy-required" :
          error.code() == HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED) ? "unavailable" : "failed";
    }
  }
  if (session->canceled) {
    completed.text.clear();
    completed.error = "canceled";
  }
  try {
    if (recognizer) recognizer.Close();
  } catch (const winrt::hresult_error& error) {
    ::OutputDebugStringW(error.message().c_str());
    if (completed.error.empty()) {
      completed.text.clear();
      completed.error = "failed";
    }
  }
  {
    std::lock_guard<std::mutex> lock(session->mutex);
    session->operation = nullptr;
  }
  recognizer = nullptr;
  session->Emit(std::move(completed));
  if (apartment_initialized) winrt::uninit_apartment();
}

class WindowsSpeechPlugin : public flutter::Plugin {
 public:
  explicit WindowsSpeechPlugin(flutter::PluginRegistrarWindows* registrar)
      : registrar_(registrar),
        window_(nullptr),
        message_(::RegisterWindowMessageW(L"SMPlayer.WinRTSpeech.Event")),
        timer_(reinterpret_cast<UINT_PTR>(this)),
        channel_(registrar->messenger(), "smplayer/windows_speech",
                 &flutter::StandardMethodCodec::GetInstance()) {
    delegate_ = registrar_->RegisterTopLevelWindowProcDelegate(
        [this](HWND, UINT message, WPARAM wparam, LPARAM) -> std::optional<LRESULT> {
          if (message == message_) {
            DrainEvents();
            return 0;
          }
          if (message == WM_TIMER && wparam == timer_) {
            ::KillTimer(window_, timer_);
            if (session_) {
              session_->Cancel();
              CompleteReply({"result", "", "timeout"});
            }
            return 0;
          }
          return std::nullopt;
        });
    channel_.SetMethodCallHandler([this](const auto& call, auto reply) {
      if (call.method_name() == "recognize") {
        if (session_) {
          reply->Error("recognition_active", "Recognition is already active.");
          return;
        }
        session_ = std::make_shared<SpeechSession>();
        window_ = ::GetAncestor(registrar_->GetView()->GetNativeWindow(), GA_ROOT);
        session_->window = window_;
        session_->message = message_;
        reply_ = std::move(reply);
        const auto language = std::get<std::string>(*call.arguments());
        ::SetTimer(window_, timer_, 18000, nullptr);
        std::thread(Recognize, session_, language).detach();
      } else if (call.method_name() == "cancel") {
        if (!session_) {
          reply->Success();
          return;
        }
        session_->Cancel();
        ::KillTimer(window_, timer_);
        CompleteReply({"result", "", "canceled"});
        reply->Success();
      } else {
        reply->NotImplemented();
      }
    });
  }

  ~WindowsSpeechPlugin() override {
    ::KillTimer(window_, timer_);
    registrar_->UnregisterTopLevelWindowProcDelegate(delegate_);
    if (session_) session_->Cancel();
  }

 private:
  void CompleteReply(const SpeechEvent& event) {
    // The watchdog/cancel path may already have replied before WinRT finishes.
    if (!reply_) return;
    reply_->Success(Value(Map{
        {Value("text"), Value(event.text)},
        {Value("error"), event.error.empty() ? Value() : Value(event.error)},
    }));
    reply_.reset();
  }

  void DrainEvents() {
    if (!session_) return;
    std::deque<SpeechEvent> events;
    {
      std::lock_guard<std::mutex> lock(session_->mutex);
      events.swap(session_->events);
    }
    for (const auto& event : events) {
      if (event.type == "result") {
        ::KillTimer(window_, timer_);
        CompleteReply(event);
        // Keep the native session reserved until cleanup actually finishes.
        // A retry during cancellation fails promptly instead of opening a
        // second recognizer against a microphone still owned by the old one.
        session_.reset();
        return;
      } else if (!session_->canceled) {
        channel_.InvokeMethod(event.type, std::make_unique<Value>(event.text));
      }
    }
  }

  flutter::PluginRegistrarWindows* registrar_;
  HWND window_;
  UINT message_;
  UINT_PTR timer_;
  int delegate_;
  flutter::MethodChannel<Value> channel_;
  std::shared_ptr<SpeechSession> session_;
  Reply reply_;
};
}  // namespace

void RegisterWindowsSpeechRecognition(flutter::PluginRegistrarWindows* registrar) {
  registrar->AddPlugin(std::make_unique<WindowsSpeechPlugin>(registrar));
}
