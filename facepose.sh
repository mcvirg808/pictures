#!/bin/bash
set -e

function init_variables() {
    print_help_if_needed $@
    script_dir=$(dirname $(realpath "$0"))
    source $script_dir/../../../../../scripts/misc/checks_before_run.sh

    readonly FACE_RESOURCES_DIR="$TAPPAS_WORKSPACE/apps/h8/gstreamer/general/face_recognition/resources"
    readonly FACE_POSTPROCESS_DIR="$TAPPAS_WORKSPACE/apps/h8/gstreamer/libs/post_processes/"
    readonly APPS_LIBS_DIR="$TAPPAS_WORKSPACE/apps/h8/gstreamer/libs/apps/vms/"
    readonly CROPPER_SO="$FACE_POSTPROCESS_DIR/cropping_algorithms/libvms_croppers.so"
    
    # Face Alignment
    readonly FACE_ALIGN_SO="$APPS_LIBS_DIR/libvms_face_align.so"
    
    # Face Recognition
    readonly RECOGNITION_POST_SO="$FACE_POSTPROCESS_DIR/libface_recognition_post.so"
    readonly RECOGNITION_HEF_PATH="$FACE_RESOURCES_DIR/arcface_mobilefacenet_v1.hef"

    # Face Detection and Landmarking
    readonly FACE_DEFAULT_HEF_PATH="$FACE_RESOURCES_DIR/scrfd_10g.hef"
    readonly FACE_POSTPROCESS_SO="$FACE_POSTPROCESS_DIR/libscrfd_post.so"
    readonly FACE_JSON_CONFIG_PATH="$FACE_RESOURCES_DIR/configs/scrfd.json"
    readonly FUNCTION_NAME="scrfd_10g"

    face_hef_path=$FACE_DEFAULT_HEF_PATH
    input_source="$FACE_RESOURCES_DIR/face_recognition.mp4"
    video_sink_element=$([ "$XV_SUPPORTED" = "true" ] && echo "xvimagesink" || echo "ximagesink")
    additional_parameters=""
    print_gst_launch_only=false
    vdevice_key=1
    function_name=$FUNCTION_NAME
    local_gallery_file="$FACE_RESOURCES_DIR/gallery/face_recognition_local_gallery.json"

    readonly POSTPROCESS_DIR="$TAPPAS_WORKSPACE/apps/h8/gstreamer/libs/post_processes/"
    readonly RESOURCES_DIR="$TAPPAS_WORKSPACE/apps/h8/gstreamer/general/pose_estimation/resources"
    readonly DEFAULT_POSTPROCESS_SO="$POSTPROCESS_DIR/libcenterpose_post.so"
    readonly DEFAULT_NETWORK_NAME="centerpose"
    readonly DEFAULT_VIDEO_SOURCE="$TAPPAS_WORKSPACE/apps/h8/gstreamer/general/detection/resources/detection.mp4"
    readonly DEFAULT_HEF_PATH="$RESOURCES_DIR/centerpose_regnetx_1.6gf_fpn.hef"

    postprocess_so=$DEFAULT_POSTPROCESS_SO
    network_name=$DEFAULT_NETWORK_NAME
    input_source=$DEFAULT_VIDEO_SOURCE
    hef_path=$DEFAULT_HEF_PATH
    network_name=$DEFAULT_NETWORK_NAME
    sync_pipeline=false

    print_gst_launch_only=false
    additional_parameters=""

    video_sink_element=$([ "$XV_SUPPORTED" = "true" ] && echo "xvimagesink" || echo "ximagesink")
    video_sink="fpsdisplaysink video-sink=$video_sink_element text-overlay=false"
}

function print_usage() {
    echo "Face recognition - pipeline usage:"
    echo ""
    echo "Options:"
    echo "  --help                          Show this help"
    echo "  --show-fps                      Printing fps"
    echo "  -i INPUT --input INPUT          Set the input source (default $input_source)"
    echo "  --network NETWORK               Set network to use. choose from [scrfd_10g, scrfd_2.5g], default is scrfd_10g"
    echo "  --print-gst-launch              Print the ready gst-launch command without running it"
	echo "  --show-fps              Printing fps"
	echo "  --tcp-address              If specified, set the sink to a TCP client (expected format is 'host:port')"
    exit 0

    # Print usage for face recognition
    # ...
}

function print_help_if_needed() {
    while test $# -gt 0; do
        if [ "$1" = "--help" ] || [ "$1" == "-h" ]; then
            print_usage
        fi
        shift
    done
	
    # Print help if needed for face recognition
    # ...
}

function parse_args() {
    while test $# -gt 0; do
        if [ "$1" = "--help" ] || [ "$1" == "-h" ]; then
            print_usage
            exit 0
        elif [ "$1" = "--print-gst-launch" ]; then
            print_gst_launch_only=true
        elif [ "$1" = "--show-fps" ]; then
            echo "Printing fps"
            additional_parameters="-v 2>&1 | grep hailo_display"
        elif [ "$1" = "--input" ] || [ "$1" == "-i" ]; then
            input_source="$2"
            shift
        elif [ $1 == "--network" ]; then
            if [ $2 == "scrfd_2.5g" ]; then
                face_hef_path="$FACE_RESOURCES_DIR/scrfd_2.5g.hef"
                function_name="scrfd_2_5g"
            elif [ $2 != "scrfd_10g" ]; then
                echo "Received invalid network: $2. See expected arguments below:"
                print_usage
                exit 1
            fi
            shift
        else
            echo "Received invalid argument: $1. See expected arguments below:"
            print_usage
            exit 1
		elif [ $1 == "--network" ]; then
            if [ $2 == "centerpose_416" ]; then
                network_name="centerpose_416"
                hef_path="$RESOURCES_DIR/centerpose_repvgg_a0.hef"
            elif [ $2 != "centerpose" ]; then
                echo "Received invalid network: $2. See expected arguments below:"
                print_usage
                exit 1
            fi
            shift
        elif [ "$1" = "--tcp-address" ]; then
            tcp_host=$(echo $2 | awk -F':' '{print $1}')
            tcp_port=$(echo $2 | awk -F':' '{print $2}')
            video_sink="queue name=queue_before_sink leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
                        x264enc tune=zerolatency ! \
                        queue max-size-bytes=0 max-size-time=0 ! matroskamux ! tcpclientsink host=$tcp_host port=$tcp_port" 

            shift
        fi
        shift
    done

    # Parse arguments for face recognition
    # ...
}

function build_pose_estimation_pipeline() {
	"videoscale ! video/x-raw, pixel-aspect-ratio=1/1 ! videoconvert ! \
    queue leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    hailonet hef-path=$pose_estimation_hef_path ! \
    queue leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    hailofilter so-path=$pose_estimation_postprocess_so qos=false function-name=$pose_estimation_network_name ! \
    queue leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    hailooverlay qos=false ! \
    videoconvert ! \
    hailoframesink name=hailo_display sync=$sync_pipeline"
}

function build_face_recognition_pipeline() {
	"queue leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    hailofilter so-path=$face_recognition_postprocess_so qos=false function-name=$face_recognition_network_name ! \
    queue leaky=no max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
    hailooverlay qos=false ! \
    videoconvert ! \
    hailoframesink name=hailo_face_recognition_display sync=$sync_pipeline"

}

function main() {
    init_variables $@
    parse_args $@
	
	    # If the video provided is from a camera
    if [[ $input_source =~ "/dev/video" ]]; then
        source_element="v4l2src device=$input_source name=src_0 ! videoflip video-direction=horiz"

		#	video/x-raw,format=YUY2,width=1920,height=1080,framerate=30/1 ! \
                #        queue  max-size-buffers=30 max-size-bytes=0 max-size-time=0 ! \
                #        videoflip video-direction=horiz"
    elif [[ $input_source =~ "rtsp://127.0.0.1:8554/office-test0" ]]; then
        source_element="rtspsrc location=$input_source name=src_0 ! decodebin"
    elif [[ $input_source =~ "rtsp://127.0.0.1:8554/office-test1" ]]; then
        source_element="rtspsrc location=$input_source name=src_0 ! decodebin"
    elif [[ $input_source =~ "rtsp://127.0.0.1:8554/office-test2" ]]; then
        source_element="rtspsrc location=$input_source name=src_0 ! decodebin"
    else
        source_element="filesrc location=$input_source name=src_0 ! decodebin"
    fi

    # Build the pose estimation pipeline
    build_pose_estimation_pipeline

    # Build the face recognition pipeline
    build_face_recognition_pipeline

    # Combine the pipelines and execute the GStreamer command
    # ...
}

main $@
