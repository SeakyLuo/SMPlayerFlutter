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
using winrt::Windows::Foundation::IAsyncOperation;
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
  std::atomic<bool> timed_out{false};
  std::mutex mutex;
  std::deque<SpeechEvent> events;
  IAsyncOperation<SpeechRecognitionResult> operation{nullptr};

  void Emit(SpeechEvent event) {
    {
      std::lock_guard<std::mutex> lock(mutex);
      events.push_back(std::move(event));
    }
    ::PostMessageW(window, message, 0, 0);
  }

  void Cancel() {
    canceled = true;
    IAsyncOperation<SpeechRecognitionResult> pending{nullptr};
    {
      std::lock_guard<std::mutex> lock(mutex);
      pending = operation;
    }
    if (pending) pending.Cancel();
  }
};

Language ResolveLanguage(const std::string& requested) {
  const Language language(winrt::to_hstring(requested));
  const auto supported = SpeechRecognizer::SupportedTopicLanguages();
  for (const auto& item : supported) {
    if (item.LanguageTag() == language.LanguageTag()) return item;
  }
  const auto tag = winrt::to_string(language.LanguageTag());
  const auto primary = tag.substr(0, tag.find('-'));
  for (const auto& item : supported) {
    if (winrt::to_string(item.LanguageTag()).rfind(primary, 0) == 0) return item;
  }
  return SpeechRecognizer::SystemSpeechLanguage();
}

void Recognize(const std::shared_ptr<SpeechSession>& session,
               const std::string& language) {
  SpeechRecognizer recognizer{nullptr};
  SpeechEvent completed{"result", "", ""};
#ifdef _DEBUG
  const auto started = std::chrono::steady_clock::now();
#endif
  try {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
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
    const auto compiled = recognizer.CompileConstraintsAsync().get();
    if (compiled.Status() != SpeechRecognitionResultStatus::Success) {
      completed.error = "unavailable";
    } else if (!session->canceled) {
      session->Emit({"state", "Capturing", ""});
      // Match Electron's recognition entry point and disabled read-back.
      const auto operation = recognizer.RecognizeWithUIAsync();
      {
        std::lock_guard<std::mutex> lock(session->mutex);
        session->operation = operation;
      }
      if (session->canceled) operation.Cancel();
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
      completed.error = error.code() == E_ACCESSDENIED ? "privacy-required" : "failed";
    }
  }
  if (session->canceled) {
    completed.text.clear();
    completed.error = session->timed_out ? "no-speech" : "canceled";
  }
  if (recognizer) recognizer.Close();
  {
    std::lock_guard<std::mutex> lock(session->mutex);
    session->operation = nullptr;
  }
  session->Emit(std::move(completed));
  winrt::uninit_apartment();
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
              session_->timed_out = true;
              session_->Cancel();
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
        cancel_replies_.push_back(std::move(reply));
        session_->Cancel();
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
        reply_->Success(Value(Map{
            {Value("text"), Value(event.text)},
            {Value("error"), event.error.empty() ? Value() : Value(event.error)},
        }));
        reply_.reset();
        session_.reset();
        for (auto& reply : cancel_replies_) reply->Success();
        cancel_replies_.clear();
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
  std::vector<Reply> cancel_replies_;
};
}  // namespace

void RegisterWindowsSpeechRecognition(flutter::PluginRegistrarWindows* registrar) {
  registrar->AddPlugin(std::make_unique<WindowsSpeechPlugin>(registrar));
}
