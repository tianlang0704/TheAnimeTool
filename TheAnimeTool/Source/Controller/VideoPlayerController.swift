//
//  VideoPlayerController.swift
//  FinalProject
//
//  Created by Tieria C.Monk on 8/18/16.
//
//

import AVKit

class VideoPlayerController: AVPlayerViewController {
    var videoEntity: Videos? = nil
    
    override func viewDidLoad() {
        guard let video = self.videoEntity else { return }
        guard let videoPath = video.videoPath else { return }
        let url = NSURL(fileURLWithPath: videoPath)
        self.player = AVPlayer(URL: url)
        self.player?.play()
    }
}
