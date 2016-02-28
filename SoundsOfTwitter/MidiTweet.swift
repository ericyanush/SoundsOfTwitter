//
//  MidiTweet.swift
//  SoundsOfTwitter
//
//  Created by Eric Yanush on 2015-12-08.
//  Copyright © 2015 EricYanush. All rights reserved.
//

import Foundation
import TwitterKit
import TwitterAPI
import MIKMIDI

class MidiTweet: Comparable {
    let rawTweet: TWTRTweet
    let events: [MIKMIDIEvent]
    
    var startTimeStamp: MusicTimeStamp {
        get {
            return events.first!.timeStamp
        }
    }
    
    var endTimeStamp: MusicTimeStamp {
        get {
            return events.last!.timeStamp
        }
    }
    
    var length: MusicTimeStamp {
        get {
            return events.last!.timeStamp - events.first!.timeStamp
        }
    }
    
    init(tweet: TWTRTweet, events: [MIKMIDIEvent]) {
        rawTweet = tweet
        self.events = events
    }
    
}

func <(lhs: MidiTweet, rhs: MidiTweet) -> Bool {
    return lhs.startTimeStamp < rhs.startTimeStamp
}

func ==(lhs: MidiTweet, rhs: MidiTweet) -> Bool {
    return lhs.startTimeStamp == rhs.startTimeStamp
}

extension Array where Element:MidiTweet {
    func nearestBinarySearch(target: MusicTimeStamp) -> Int {
        var left = 0
        var right = self.count - 1
        
        if self.count > 0 {
            if target < self.first!.startTimeStamp {
                return 0
            }
            else if target > self.last!.startTimeStamp {
                return (self.count - 1)
            }
        }
        
        while left <= right {
            let middle = (left + right) / 2
            let val = self[middle]
            
            if (val.startTimeStamp == target) {
                return middle
            }
            else if (val.startTimeStamp < target) {
                //check if the next element is > target
                if (middle + 1) < self.count && self[middle+1].startTimeStamp > target {
                    // we are in between the two, round to nearest one
                    let nextVal = self[middle+1]
                    let leftDist = abs(target - val.startTimeStamp)
                    let rightDist = abs(nextVal.startTimeStamp - target)
                    if leftDist < rightDist {
                        return middle
                    }
                    else {
                        return (middle + 1)
                    }
                }
                else {
                    left = middle + 1
                }
            }
            else if (val.startTimeStamp > target) {
                // check if prev element is < target
                if (middle - 1) > 0 && self[middle-1].startTimeStamp < target {
                    // we are between the two, round to the nearest
                    let prevVal = self[middle-1]
                    let leftDist = abs(target - prevVal.startTimeStamp)
                    let rightDist = abs(val.startTimeStamp - target)
                    if leftDist < rightDist {
                        return (middle - 1)
                    }
                    else {
                        return middle
                    }
                }
                else {
                    right = middle - 1
                }
            }
        }
        return 0
    }

}