#!/usr/bin/env python3
"""YOLOv11 face detection streaming to TCP"""
import cv2
from ultralytics import YOLO
from huggingface_hub import hf_hub_download
import argparse
import subprocess
import sys
import time
import torch
import threading

def main():
    parser = argparse.ArgumentParser(description='YOLOv11 face detection → TCP stream')
    parser.add_argument('--source', required=True, help='Video file or NDI source')
    parser.add_argument('--port', type=int, default=1377, help='TCP port (default: 1377)')
    parser.add_argument('--loop', action='store_true', help='Loop video files')
    parser.add_argument('--conf', type=float, default=0.25, help='Confidence threshold')
    args = parser.parse_args()
    
    print(f"CUDA: {torch.cuda.is_available()}", file=sys.stderr)
    
    # Load model and open source
    model = YOLO(hf_hub_download("AdamCodd/YOLOv11n-face-detection", "model.pt"))

    cap = cv2.VideoCapture(args.source)
    if not cap.isOpened():
        print(f"ERROR: Cannot open {args.source}", file=sys.stderr)
        return 1
    
    # Get video properties
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = int(cap.get(cv2.CAP_PROP_FPS))
    
    
    print(f"Source: {args.source} ({width}x{height} @ {fps}fps)", file=sys.stderr)
    
    # Start ffmpeg TCP stream
    ffmpeg = subprocess.Popen([
        'ffmpeg', '-f', 'rawvideo', '-pix_fmt', 'bgr24',
        '-s', f'{width}x{height}', '-r', str(fps), '-i', '-',
        '-f', 'mpegts', f'tcp://0.0.0.0:{args.port}?listen=1'
    ], stdin=subprocess.PIPE)
    print(f"FFmpeg listening on tcp://0.0.0.0:{args.port}", file=sys.stderr)
    
    # Shared state  
    latest_raw_frame = None
    current_frame = None
    frame_lock = threading.Lock()
    running = True
    
    # Reader thread - drain buffer at full camera speed
    def read_frames():
        nonlocal latest_raw_frame, running
        while running:
            ret, frame = cap.read()
            if not ret:
                if args.loop:
                    cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    continue
                running = False
                break
            with frame_lock:
                latest_raw_frame = frame
    
    # Processing thread - grab latest, run YOLO
    def process_frames():
        nonlocal current_frame, running
        process_width = width // 2
        process_height = height // 2
        
        process_count = 0
        while running:
            t0 = time.time()
            
            # Grab latest raw frame
            with frame_lock:
                if latest_raw_frame is None:
                    time.sleep(0.001)
                    continue
                frame = latest_raw_frame.copy()
            t1 = time.time()
            
            # Resize and process
            small = cv2.resize(frame, (process_width, process_height))
            results = model(small, conf=args.conf, verbose=False, device='cuda')
            t2 = time.time()
            
            annotated_small = results[0].plot()
            annotated = cv2.resize(annotated_small, (width, height))
            t3 = time.time()
            
            with frame_lock:
                current_frame = annotated
            
            process_count += 1
            if process_count % 30 == 0:
                print(f"Processor: grab={1000*(t1-t0):.1f}ms YOLO={1000*(t2-t1):.1f}ms plot+resize={1000*(t3-t2):.1f}ms total={1000*(t3-t0):.1f}ms", file=sys.stderr)
    
    # Start both threads
    reader = threading.Thread(target=read_frames, daemon=True)
    processor = threading.Thread(target=process_frames, daemon=True)
    reader.start()
    processor.start()
    
    # Wait for first frame
    while current_frame is None and running:
        time.sleep(0.01)
    
    print("Streaming at fixed 30fps...", file=sys.stderr)
    
    # Stream at fixed fps
    frame_time = 1.0 / fps
    output_count = 0
    try:
        while running:
            start = time.time()
            
            with frame_lock:
                if current_frame is not None:
                    ffmpeg.stdin.write(current_frame.tobytes())
            
            output_count += 1
            if output_count % 30 == 0:
                elapsed = time.time() - start
                # print(f"Output: frame {output_count}, write={1000*elapsed:.1f}ms", file=sys.stderr)
            
            # Maintain fixed framerate
            elapsed = time.time() - start
            sleep_time = frame_time - elapsed
            if sleep_time > 0:
                time.sleep(sleep_time)
                
    except KeyboardInterrupt:
        pass
    except BrokenPipeError:
        pass
    finally:
        running = False
        cap.release()
        ffmpeg.terminate()
        ffmpeg.wait()

if __name__ == '__main__':
    sys.exit(main() or 0)
