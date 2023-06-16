#!/bin/bash
set -e

function init_variables() {
    # Remaining code...
    # Initialize other variables
    rtsp_source_1="rtsp://127.0.0.1:8554/office-test"
    rtsp_source_2="rtsp://127.0.0.1:8554/office-test2"
    rtsp_source_3="rtsp://127.0.0.1:8554/office-test3"
}

function main() {
    init_variables $@
    parse_args $@

    # Check if the input source is an RTSP stream
    if [[ $input_source =~ "rtsp://" ]]; then
        # Create a branch for each RTSP stream
        pipeline="gst-launch-1.0 \
            tee name=t \
            t. ! queue leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
                rtspsrc location=$rtsp_source_1 ! decodebin ! videoconvert ! \
                queue name=hailo_pre_convert_0 leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
                videoconvert n-threads=2 qos=false ! \
                queue name=pre_detector_q leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
                $DETECTOR_PIPELINE ! \
                queue name=pre_tracker_q leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
                $FACE_TRACKER ! \
                queue name=hailo_post_tracker_q leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
                $RECOGNITION_PIPELINE ! \
                queue name=hailo_pre_gallery_q leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
                hailogallery gallery-file-path=$local_gallery_file \
                load-local-gallery=true similarity-thr=.4 gallery-queue-size=20 class-id=-1 ! \
                queue name=hailo_pre_draw2 leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
                hailooverlay name=hailo_overlay qos=false show-confidence=false local-gallery=true line-thickness=5 font-thickness=2 landmark-point-radius=8 ! \
                queue name=hailo_post_draw leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
                videoconvert n-threads=4 qos=false name=display_videoconvert qos=false ! \
                queue name=hailo_display_q_0 leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
                fpsdisplaysink video-sink=$video_sink_element name=hailo_display sync=false text-overlay=false \
                ${additional_parameters}"                
    else
        # If the input source is not an RTSP stream, use the existing logic
        pipeline="gst-launch-1.0 \
            $source_element ! \
            queue name=hailo_pre_convert_0 leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
            videoconvert n-threads=2 qos=false ! \
            queue name=pre_detector_q leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
            $DETECTOR_PIPELINE ! \
            queue name=pre_tracker_q leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
            $FACE_TRACKER ! \
            queue name=hailo_post_tracker_q leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
            $RECOGNITION_PIPELINE ! \
            queue name=hailo_pre_gallery_q leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
            hailogallery gallery-file-path=$local_gallery_file \
            load-local-gallery=true similarity-thr=.4 gallery-queue-size=20 class-id=-1 ! \
            queue name=hailo_pre_draw2 leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
            hailooverlay name=hailo_overlay qos=false show-confidence=false local-gallery=true line-thickness=5 font-thickness=2 landmark-point-radius=8 ! \
            queue name=hailo_post_draw leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
            videoconvert n-threads=4 qos=false name=display_videoconvert qos=false ! \
            queue name=hailo_display_q_0 leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
            fpsdisplaysink video-sink=$video_sink_element name=hailo_display sync=false text-overlay=false \
            ${additional_parameters}"
    fi

    # Print the generated pipeline
    echo "Pipeline: $pipeline"

    # Run the pipeline
    eval $pipeline
}

# Remaining code...

main $@