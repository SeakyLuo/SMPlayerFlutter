#!/usr/bin/env python3
import struct
import sys
import zlib
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def read_png(path):
    data = Path(path).read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"{path} is not a PNG")

    offset = len(PNG_SIGNATURE)
    width = height = color_type = None
    chunks = []
    compressed = bytearray()
    while offset < len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        chunk_type = data[offset + 4 : offset + 8]
        chunk_data = data[offset + 8 : offset + 8 + length]
        offset += 12 + length
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(
                ">IIBBBBB", chunk_data
            )
            if bit_depth != 8 or compression != 0 or filter_method != 0 or interlace != 0:
                raise ValueError(f"{path} uses unsupported PNG parameters")
            if color_type not in (2, 6):
                raise ValueError(f"{path} uses unsupported color type {color_type}")
        elif chunk_type == b"IDAT":
            compressed.extend(chunk_data)
        elif chunk_type == b"IEND":
            break
        chunks.append((chunk_type, chunk_data))

    channels = 4 if color_type == 6 else 3
    stride = width * channels
    raw = zlib.decompress(bytes(compressed))
    rows = []
    pos = 0
    previous = [0] * stride
    for _ in range(height):
        filter_type = raw[pos]
        pos += 1
        scanline = list(raw[pos : pos + stride])
        pos += stride
        recon = unfilter(scanline, previous, channels, filter_type)
        previous = recon
        if channels == 3:
            rgba = []
            for index in range(0, len(recon), 3):
                rgba.extend([recon[index], recon[index + 1], recon[index + 2], 255])
            rows.append(rgba)
        else:
            rows.append(recon)
    return width, height, rows


def unfilter(scanline, previous, channels, filter_type):
    result = scanline[:]
    if filter_type == 0:
        return result
    if filter_type == 1:
        for index in range(len(result)):
            left = result[index - channels] if index >= channels else 0
            result[index] = (result[index] + left) & 0xFF
        return result
    if filter_type == 2:
        for index in range(len(result)):
            result[index] = (result[index] + previous[index]) & 0xFF
        return result
    if filter_type == 3:
        for index in range(len(result)):
            left = result[index - channels] if index >= channels else 0
            up = previous[index]
            result[index] = (result[index] + ((left + up) // 2)) & 0xFF
        return result
    if filter_type == 4:
        for index in range(len(result)):
            left = result[index - channels] if index >= channels else 0
            up = previous[index]
            up_left = previous[index - channels] if index >= channels else 0
            result[index] = (result[index] + paeth(left, up, up_left)) & 0xFF
        return result
    raise ValueError(f"unsupported PNG filter {filter_type}")


def paeth(left, up, up_left):
    estimate = left + up - up_left
    left_delta = abs(estimate - left)
    up_delta = abs(estimate - up)
    up_left_delta = abs(estimate - up_left)
    if left_delta <= up_delta and left_delta <= up_left_delta:
        return left
    if up_delta <= up_left_delta:
        return up
    return up_left


def write_png(path, width, height, rows):
    raw = bytearray()
    for row in rows:
        raw.append(0)
        raw.extend(row)
    compressed = zlib.compress(bytes(raw), level=6)
    output = bytearray(PNG_SIGNATURE)
    output.extend(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
    output.extend(chunk(b"IDAT", compressed))
    output.extend(chunk(b"IEND", b""))
    Path(path).write_bytes(output)


def chunk(chunk_type, data):
    body = chunk_type + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def compare_rows(left_rows, right_rows, width, height):
    total_channels = width * height * 3
    total_pixels = width * height
    abs_sum = 0
    max_delta = 0
    different_pixels = 0
    over_16_pixels = 0
    for y in range(height):
        left = left_rows[y]
        right = right_rows[y]
        for x in range(width):
            index = x * 4
            deltas = [
                abs(left[index] - right[index]),
                abs(left[index + 1] - right[index + 1]),
                abs(left[index + 2] - right[index + 2]),
            ]
            pixel_delta = max(deltas)
            abs_sum += sum(deltas)
            max_delta = max(max_delta, pixel_delta)
            if pixel_delta:
                different_pixels += 1
            if pixel_delta > 16:
                over_16_pixels += 1
    return {
        "mean_abs_rgb": abs_sum / total_channels,
        "max_delta": max_delta,
        "different_pixel_percent": different_pixels * 100 / total_pixels,
        "over_16_pixel_percent": over_16_pixels * 100 / total_pixels,
    }


def background_color(rows, width, height):
    samples = []
    sample_size = 12
    corners = [
        (0, 0),
        (width - sample_size, 0),
        (0, height - sample_size),
        (width - sample_size, height - sample_size),
    ]
    for start_x, start_y in corners:
        for y in range(start_y, start_y + sample_size):
            row = rows[y]
            for x in range(start_x, start_x + sample_size):
                index = x * 4
                samples.append(row[index : index + 3])
    return [
        sorted(sample[channel] for sample in samples)[len(samples) // 2]
        for channel in range(3)
    ]


def color_distance(left, right):
    return max(abs(left[index] - right[index]) for index in range(3))


def detect_foreground_bounds(rows, width, height):
    bg = background_color(rows, width, height)
    xs = []
    ys = []
    threshold = 10
    for y in range(height):
        row = rows[y]
        for x in range(width):
            index = x * 4
            if color_distance(row[index : index + 3], bg) > threshold:
                xs.append(x)
                ys.append(y)
    if not xs:
        return (0, 0, width, height)
    margin = 2
    left = max(0, min(xs) - margin)
    top = max(0, min(ys) - margin)
    right = min(width, max(xs) + margin + 1)
    bottom = min(height, max(ys) + margin + 1)
    return (left, top, right, bottom)


def crop_rows(rows, bounds):
    left, top, right, bottom = bounds
    cropped = []
    for y in range(top, bottom):
        row = rows[y]
        cropped.append(row[left * 4 : right * 4])
    return right - left, bottom - top, cropped


def pad_rows(rows, width, height, target_width, target_height, color=None):
    color = color or [244, 246, 250, 255]
    left_pad = max(0, (target_width - width) // 2)
    right_pad = max(0, target_width - width - left_pad)
    top_pad = max(0, (target_height - height) // 2)
    bottom_pad = max(0, target_height - height - top_pad)
    pad_left = color * left_pad
    pad_right = color * right_pad
    empty = color * target_width
    padded = [empty[:] for _ in range(top_pad)]
    for row in rows:
        padded.append(pad_left + row + pad_right)
    padded.extend(empty[:] for _ in range(bottom_pad))
    return padded


def cropped_pair(left_rows, right_rows, width, height, dialog_rect=None):
    if dialog_rect is None:
        left_bounds = detect_foreground_bounds(left_rows, width, height)
        right_bounds = detect_foreground_bounds(right_rows, width, height)
    else:
        x, y, crop_width, crop_height = dialog_rect
        bounds = (x, y, x + crop_width, y + crop_height)
        left_bounds = bounds
        right_bounds = bounds
    left_crop_width, left_crop_height, left_crop = crop_rows(left_rows, left_bounds)
    right_crop_width, right_crop_height, right_crop = crop_rows(right_rows, right_bounds)
    target_width = max(left_crop_width, right_crop_width)
    target_height = max(left_crop_height, right_crop_height)
    left_padded = pad_rows(left_crop, left_crop_width, left_crop_height, target_width, target_height)
    right_padded = pad_rows(right_crop, right_crop_width, right_crop_height, target_width, target_height)
    return {
        "left_bounds": left_bounds,
        "right_bounds": right_bounds,
        "width": target_width,
        "height": target_height,
        "left_rows": left_padded,
        "right_rows": right_padded,
    }


def side_by_side(left_rows, right_rows, width, height, gap=24):
    rows = []
    gap_pixel = [244, 246, 250, 255]
    gap_row = gap_pixel * gap
    for y in range(height):
        rows.append(left_rows[y] + gap_row + right_rows[y])
    return width * 2 + gap, height, rows


def parse_dialog_rect(value):
    parts = value.split(",")
    if len(parts) != 4:
        raise ValueError("--dialog-rect must be x,y,width,height")
    rect = tuple(int(part) for part in parts)
    if rect[2] <= 0 or rect[3] <= 0:
        raise ValueError("--dialog-rect width and height must be positive")
    return rect


def main():
    args = sys.argv[1:]
    dialog_rect = None
    if args[:1] == ["--dialog-rect"]:
        if len(args) < 2:
            raise SystemExit("--dialog-rect requires x,y,width,height")
        dialog_rect = parse_dialog_rect(args[1])
        args = args[2:]

    if len(args) < 3 or len(args) % 3 != 0:
        raise SystemExit(
            "usage: music_dialog_screenshot_compare.py [--dialog-rect x,y,width,height] "
            "<name> <left.png> <right.png> [<name> <left.png> <right.png>...]"
        )

    for index in range(0, len(args), 3):
        name, left_path, right_path = args[index : index + 3]
        left_width, left_height, left_rows = read_png(left_path)
        right_width, right_height, right_rows = read_png(right_path)
        if (left_width, left_height) != (right_width, right_height):
            raise ValueError(f"{name}: size mismatch {left_width}x{left_height} vs {right_width}x{right_height}")
        if dialog_rect is not None:
            x, y, crop_width, crop_height = dialog_rect
            if x < 0 or y < 0 or x + crop_width > left_width or y + crop_height > left_height:
                raise ValueError(f"{name}: --dialog-rect is outside {left_width}x{left_height}")
        stats = compare_rows(left_rows, right_rows, left_width, left_height)
        out_path = f"/tmp/smplayer_music_dialog_compare_{name}.png"
        out_width, out_height, out_rows = side_by_side(left_rows, right_rows, left_width, left_height)
        write_png(out_path, out_width, out_height, out_rows)
        cropped = cropped_pair(left_rows, right_rows, left_width, left_height, dialog_rect)
        cropped_stats = compare_rows(
            cropped["left_rows"],
            cropped["right_rows"],
            cropped["width"],
            cropped["height"],
        )
        cropped_out_path = f"/tmp/smplayer_music_dialog_compare_{name}_cropped.png"
        cropped_out_width, cropped_out_height, cropped_out_rows = side_by_side(
            cropped["left_rows"],
            cropped["right_rows"],
            cropped["width"],
            cropped["height"],
        )
        write_png(cropped_out_path, cropped_out_width, cropped_out_height, cropped_out_rows)
        print(
            f"{name}: side_by_side={out_path} "
            f"mean_abs_rgb={stats['mean_abs_rgb']:.2f} "
            f"max_delta={stats['max_delta']} "
            f"different_pixels={stats['different_pixel_percent']:.2f}% "
            f"over_16={stats['over_16_pixel_percent']:.2f}% "
            f"cropped_side_by_side={cropped_out_path} "
            f"crop_source={'fixed' if dialog_rect is not None else 'auto'} "
            f"cropped_size={cropped['width']}x{cropped['height']} "
            f"left_bounds={cropped['left_bounds']} "
            f"right_bounds={cropped['right_bounds']} "
            f"cropped_mean_abs_rgb={cropped_stats['mean_abs_rgb']:.2f} "
            f"cropped_over_16={cropped_stats['over_16_pixel_percent']:.2f}%"
        )


if __name__ == "__main__":
    main()
