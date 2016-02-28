//
//  ViewController.swift
//  SoundsOfTwitter
//
//  Created by Eric Yanush on 2015-11-24.
//  Copyright © 2015 EricYanush. All rights reserved.
//

import UIKit
import TwitterAPI
import SwiftyJSON
import MIKMIDI
import MusicKit
import TwitterKit

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, TWTRTweetViewDelegate, UISearchBarDelegate {
    
    @IBOutlet weak var tweetTable: UITableView?
    private var tweets = [MidiTweet]()
    
    @IBOutlet weak var searchBar: UISearchBar?
    private var searchController: UISearchController?
    
    @IBOutlet weak var noteStackView: UIStackView?
    @IBOutlet weak var minOctStackView: UIStackView?
    @IBOutlet weak var maxOctStackView: UIStackView?
    @IBOutlet weak var scaleStackView: UIStackView?
    
    @IBOutlet weak var noteSlider: UISlider?
    @IBOutlet weak var noteLabel: UILabel?
    
    @IBOutlet weak var scaleSlider: UISlider?
    @IBOutlet weak var scaleLabel: UILabel?
    
    @IBOutlet weak var maxOctSlider: UISlider?
    @IBOutlet weak var maxOctLabel: UILabel?
    
    @IBOutlet weak var minOctSlider: UISlider?
    @IBOutlet weak var minOctLabel: UILabel?
    
    @IBOutlet weak var processorTypeSelector: UISegmentedControl?
    
    var trackString: String = ""
    
    var client : OAuthClient?
    let streamingURL = "https://stream.twitter.com/1.1/statuses/filter.json"
    var request: StreamingRequest?
    var sequence = MIKMIDISequence()
    var sequencer = MIKMIDISequencer()
    var track: MIKMIDITrack?
    var synth: MIKMIDISynthesizer?
    //var firstTimeStamp: Int64 = Int64(NSDate().timeIntervalSince1970) * 1000
    var firstTimeStamp = NSDate()
    //var lastTimeStamp: Int64 = 0
    var lastTimeStamp = NSDate()
    var eventsProcessed: Int64 = 0
    var tweetsProcessed: Int64 = 0
    
    var tweetProcessor: TweetProcessor.Type = WordRandomProcessor.self
    
    let notesSet: PitchSet = Scale.Chromatic(Pitch(chroma: Chroma.A, octave: 0)) +
                             Scale.Chromatic(Pitch(chroma: Chroma.A, octave: 1)) +
                             Scale.Chromatic(Pitch(chroma: Chroma.A, octave: 2)) +
                             Scale.Chromatic(Pitch(chroma: Chroma.A, octave: 3)) +
                             Scale.Chromatic(Pitch(chroma: Chroma.A, octave: 4)) +
                             Scale.Chromatic(Pitch(chroma: Chroma.A, octave: 5)) +
                             Scale.Chromatic(Pitch(chroma: Chroma.A, octave: 6)) +
                             Scale.Chromatic(Pitch(chroma: Chroma.A, octave: 7)) +
                             Scale.Chromatic(Pitch(chroma: Chroma.A, octave: 8))
    
    let scaleSet: [Harmonizer] = [Scale.Chromatic, Scale.Dorian, Scale.Locrian, Scale.Lydian,
                             Scale.Major, Scale.Minor, Scale.Mixolydian, Scale.Octatonic1,
                             Scale.Octatonic2, Scale.Phrygian, Scale.Wholetone]
    let scaleSetLabels: [String] = ["Chromatic", "Dorian", "Locrian", "Lydian",
                                   "Major", "Minor", "Mixolydian", "Octatonic 1",
                                   "Octatonic 2", "Phrygian", "Wholetone"]

    func progressHandler(data: NSData) {
        let tweetJSON = JSON(data: data)
        let tweet = TWTRTweet(JSONDictionary: tweetJSON.dictionaryObject)
        
        //Tweets are loaded individually, so we have exactly one tweet to process here
        let midiTweet = tweetProcessor.processTweet(tweet, baseTimeStamp: track!.length)
        //Compute frequency
        
        let currDate = tweet.createdAt
        if lastTimeStamp == firstTimeStamp {
            lastTimeStamp = currDate
            eventsProcessed += tweet.text.componentsSeparatedByString(" ").count
            tweetsProcessed += 1
            print("Playing tweet: \(tweet.text), at tempo: \(200.0)")
        }
        else {
            let tweetsPerMin: Double = 1 / ((currDate.timeIntervalSinceDate(firstTimeStamp) / (60.0)) / Double(tweetsProcessed - 1))
            //lastTimeStamp = currStamp
            lastTimeStamp = currDate
            eventsProcessed += tweet.text.componentsSeparatedByString(" ").count
            tweetsProcessed += 1
            let tempo = tweetsPerMin * Double(eventsProcessed/tweetsProcessed) // Tweets/Minute * avg events/tweet
            let currOffset = track!.length - sequencer.currentTimeStamp
            sequencer.tempo = max(tempo + (currOffset * 0.01), 20.0)
            print("Playing tweet: \(tweet.text), at tempo: \(tempo)")
        }
    
        track!.addEvents(midiTweet.events)
        print("Current offset is \(track!.length - sequencer.currentTimeStamp)")
        if !sequencer.playing {
           sequencer.resumePlayback()
        }
        //Add the new tweet to the ui
        dispatch_async(dispatch_get_main_queue()) {
            self.insertTweet(midiTweet)
        }
    }
    
    func completionHandler(responseData: NSData?, response: NSURLResponse?, error: NSError?) {
        if let data = responseData {
            print(String(data: data, encoding: NSUTF8StringEncoding))
        }
        if let e = error {
            print(e)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //Setup the tweet table
        self.tweetTable?.registerClass(TWTRTweetTableViewCell.self, forCellReuseIdentifier: "tweetCell")
        
        //Setup for processor selection
        processorTypeSelector?.addTarget(self, action: "processorSelectionChange", forControlEvents: .ValueChanged)
        processorTypeSelector?.selectedSegmentIndex = ProcessorType.SingleNote.rawValue
        processorSelectionChange()
        setupUIControlsForProcessor(.SingleNote)
        
        //Setup for min octave change
        minOctSlider?.addTarget(self, action: "minOctaveChange", forControlEvents: .ValueChanged)
        minOctSlider?.continuous = true
        minOctSlider?.addTarget(self, action: "handleMinOctaveChange", forControlEvents: .TouchUpInside)
        minOctSlider?.minimumValue = 0.0
        minOctSlider?.maximumValue = 8.0
        minOctSlider?.value = 2.0
        minOctLabel?.text = String(Int(minOctSlider!.value))
        
        //Setup for max octave change
        maxOctSlider?.addTarget(self, action: "maxOctaveChange", forControlEvents: .ValueChanged)
        maxOctSlider?.continuous = true
        maxOctSlider?.addTarget(self, action: "handleMaxOctaveChange", forControlEvents: .TouchUpInside)
        maxOctSlider?.minimumValue = 0.0
        maxOctSlider?.maximumValue = 8.0
        maxOctSlider?.value = 7.0
        maxOctLabel?.text = String(Int(maxOctSlider!.value))
        
        //Setup for note change
        noteSlider?.addTarget(self, action: "noteChange", forControlEvents: .ValueChanged)
        noteSlider?.continuous = true
        noteSlider?.addTarget(self, action: "handleNoteChange", forControlEvents: .TouchUpInside)
        noteSlider?.minimumValue = 0.0
        noteSlider?.maximumValue = Float(notesSet.count - 1)
        noteSlider?.value = 0
        noteLabel?.text = notesSet[Int(noteSlider!.value)].noteName!
        
        //Setup for scale change
        scaleSlider?.addTarget(self, action: "scaleChange", forControlEvents: .ValueChanged)
        scaleSlider?.continuous = true
        scaleSlider?.addTarget(self, action: "handleScaleChange", forControlEvents: .TouchUpInside)
        scaleSlider?.maximumValue = 0.0
        scaleSlider?.maximumValue = Float(scaleSet.count - 1)
        scaleSlider?.value = 0
        scaleLabel!.text = labelForScaleSetIndex(0)
        
        //setup the track
        track = sequence.addTrack()
        guard (track != nil) else {
            print("Error creating track")
            return
        }
        sequencer.sequence = sequence
        //Set the default tempo to 200 bpm
        sequence.setTempo(200.0, atTimeStamp: MusicTimeStamp(0))
        sequencer.addObserver(self, forKeyPath: "playing", options: .New, context: nil)
        //Cheat and use the latestScheduledTimeStamp as a callback for currentTimeStamp, so we can update the ui
        sequencer.addObserver(self, forKeyPath: "latestScheduledMIDITimeStamp", options: .New, context: nil)
        let fontURL = NSBundle.mainBundle().URLForResource("9ftgrand", withExtension: "sf2")
        synth = MIKMIDISynthesizer()!
        do {
            try synth!.loadSoundfontFromFileAtURL(fontURL!)
        }
        catch {
            print("Error loading synth sound font")
        }
        sequencer.setCommandScheduler(synth, forTrack: track!)
        WordRandomProcessor.minVal = 36
        WordScaleProcessor.minOctave = 1
        WordScaleProcessor.maxOctave = 7
        WordScaleProcessor.setScale(Chroma.E, scaleType: Scale.Phrygian)
       
        //setup search bar
        searchBar?.delegate = self
        
        //Setup the TwitterAPI client
        client = OAuthClient(consumerKey: "qsTb8wKgtYTnY1zt5U3U27Khg",
            consumerSecret: "SaNQKyEL3msDgPxYUulhiepFsKgyn32HtZwljnOKNHK9DdOgpX",
            accessToken: "432349035-McQ2IaNCdVTqOcFlWedYgZaItLF6JWt9aEkuC07G",
            accessTokenSecret: "jEF8usN9NVptVJsRJHuKjotBoRRSRi7OVOwgRzeN7canw")
        
        //Create an api request
        trackString = "YearInMusic"
        searchBar?.text = trackString
        request = client!.streaming(streamingURL, parameters: ["track": trackString])
        .progress(progressHandler).completion(completionHandler).start()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        //Stop the request to avoid getting any more data during the time we are cleaning up
        request?.stop()
        //pause the sequencer
        sequencer.stop()
        //destroy any already played content
        track?.cutEventsFromStartingTimeStamp(MusicTimeStamp(0), toEndingTimeStamp: sequencer.currentTimeStamp)
        //destroy everything but the last 50 tweets
        clearTweetsBeforeIndex(50)
        //restart playback and the request
        sequencer.startPlayback()
        request = client?.streaming(streamingURL, parameters: ["track": trackString])
        .progress(progressHandler).completion(completionHandler).start()
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        return
    }
    
    func insertTweet(tweet: MidiTweet) {
        tweetTable!.beginUpdates()
        tweets.append(tweet)
        tweetTable!.insertRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .Automatic)
        tweetTable!.endUpdates()
    }
    
    func clearAllTweets() {
        tweetTable!.beginUpdates()
        var indexPaths = [NSIndexPath]()
        for var i = 0; i < tweets.count; i++ {
            indexPaths.append(NSIndexPath(forRow: i, inSection: 0))
        }
        tweets.removeAll()
        tweetTable!.deleteRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
        tweetTable!.endUpdates()
    }
    
    func clearTweetsBeforeIndex(index: Int) {
        // If we already have less, do nothing
        if (index + 1) > tweets.count {
            return
        }
        
        tweetTable?.beginUpdates()
        var indexPaths = [NSIndexPath]()
        for var i = index + 1; i < tweets.count; i++ {
            indexPaths.append(NSIndexPath(forRow: i, inSection: 0))
        }
        tweets.removeRange(index...tweets.count)
        tweetTable?.deleteRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
        tweetTable?.endUpdates()
    }
    
    func reprocessAllFutureEvents() {
        request?.stop()
        sequencer.stop()
        let nearestTweet = tweets.nearestBinarySearch(sequencer.currentTimeStamp)
        var newTweets = [MidiTweet]()
        track!.removeAllEvents()
        
        var ts = MusicTimeStamp(0)
        for var i = nearestTweet; i < tweets.count; i++ {
            let t = tweetProcessor.processTweet(tweets[i].rawTweet, baseTimeStamp: ts)
            ts = t.endTimeStamp
            newTweets.append(t)
            track?.addEvents(t.events)
        }
        
        var removePaths = [NSIndexPath]()
        for var i = 0; i < tweets.count; i++ {
            removePaths.append(NSIndexPath(forRow: i, inSection: 0))
        }
        var insertPaths = [NSIndexPath]()
        for var i = 0; i < newTweets.count; i++ {
            insertPaths.append(NSIndexPath(forRow: i, inSection: 0))
        }
        tweetTable?.beginUpdates()
        tweetTable?.deleteRowsAtIndexPaths(removePaths, withRowAnimation: .Automatic)
        tweets = newTweets
        tweetTable?.insertRowsAtIndexPaths(insertPaths, withRowAnimation: .Automatic)
        tweetTable?.endUpdates()
        
        sequencer.startPlayback()
        request = client?.streaming(streamingURL, parameters: ["track": trackString]).progress(progressHandler).completion(completionHandler).start()
    }
    
    //UI Handlers
    enum ProcessorType: Int {
        case SingleNote = 0
        case RandomNote = 1
        case Scale = 2
    }
    
    func processorSelectionChange() {
        let newVal = ProcessorType(rawValue: (processorTypeSelector?.selectedSegmentIndex)!)!
        switch newVal {
        case .SingleNote:
            tweetProcessor = WordSingleToneProcessor.self
            break
        case .RandomNote:
            tweetProcessor = WordRandomProcessor.self
            break
        case .Scale:
            tweetProcessor = WordScaleProcessor.self
            break
        }
        //pause sequencer playback, and convert the upcoming events
        if track != nil {
            reprocessAllFutureEvents()
            setupUIControlsForProcessor(newVal)
        }
    }
    
    func handleMinOctaveChange() {
        //update all future events
        reprocessAllFutureEvents()
    }
    
    func minOctaveChange() {
        let newVal = Int(minOctSlider!.value)
        minOctLabel?.text = String(newVal)
        //Update the relevant processors
        WordRandomProcessor.minVal = UInt8((newVal) * 12) + 21
        WordScaleProcessor.minOctave = UInt8(newVal)
    }
    
    func handleMaxOctaveChange() {
        //update all future events
        reprocessAllFutureEvents()
    }
    
    func maxOctaveChange() {
        let newVal = Int(maxOctSlider!.value)
        maxOctLabel?.text = String(newVal)
        //Update relevant processors
        WordRandomProcessor.maxVal = UInt8((newVal) * 12) + 21
        WordScaleProcessor.maxOctave = UInt8(newVal)
    }
    
    func handleNoteChange() {
        let newVal = Int(noteSlider!.value)
        
        //Update The relevant processors
        WordSingleToneProcessor.tone = UInt8(notesSet[newVal].midi)
        
        let scaleVal = Int(scaleSlider!.value)
        WordScaleProcessor.setScale(notesSet[newVal].chroma!, scaleType: scaleSet[scaleVal])
        
        //update all the notes in the track
        reprocessAllFutureEvents()
    }
    
    func noteChange() {
        let newVal = Int(noteSlider!.value)
        let label = notesSet[newVal].noteName!
        noteLabel?.text = label
    }
   
    func handleScaleChange() {
        //reprocess all future events
        reprocessAllFutureEvents()
    }
    
    func scaleChange() {
        let newVal = Int(scaleSlider!.value)
        let label = scaleSetLabels[newVal]
        scaleLabel?.text = label
        
        let noteVal = Int(noteSlider!.value)
        
        //Upate the relevant processor
        WordScaleProcessor.setScale(notesSet[noteVal].chroma!, scaleType: scaleSet[newVal])
    }
    
    func setupUIControlsForProcessor(processor: ProcessorType) {
        switch processor {
        case .SingleNote:
            //Show only note selector
            noteStackView?.hidden = false
            minOctStackView?.hidden = true
            maxOctStackView?.hidden = true
            scaleStackView?.hidden = true
            break
        case .RandomNote:
            //Show only min/max octave
            noteStackView?.hidden = true
            minOctStackView?.hidden = false
            maxOctStackView?.hidden = false
            scaleStackView?.hidden = true
            break
        case .Scale:
            //Show note and scale selector
            noteStackView?.hidden = false
            minOctStackView?.hidden = false
            maxOctStackView?.hidden = false
            scaleStackView?.hidden = false
            break
        }
    }
    
    func labelForScaleSetIndex(index: Int) -> String {
        if index < 0 || index > (scaleSetLabels.count - 1) {
            return ""
        }
        return scaleSetLabels[index]
    }
    
    //Tweet table view controller datasource methods
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = self.tweetTable?.dequeueReusableCellWithIdentifier("tweetCell", forIndexPath: indexPath)
        let arrIndex = tweets.count - indexPath.row - 1
        if let tweetCell = cell as? TWTRTweetTableViewCell {
            tweetCell.configureWithTweet(tweets[arrIndex].rawTweet)
            tweetCell.tweetView.delegate = self
            return tweetCell
        }
        else {
            let tweetCell = TWTRTweetTableViewCell()
            tweetCell.configureWithTweet(tweets[arrIndex].rawTweet)
            tweetCell.tweetView.delegate = self
            return tweetCell
        }
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let arrIndex = tweets.count - indexPath.row - 1
        return TWTRTweetTableViewCell.heightForTweet(tweets[arrIndex].rawTweet, width: tableView.frame.width)
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tweets.count
    }
    
    func trackTwitterString(string: String) {
        trackString = string
        //stop the request
        request?.stop()
        //Stop the sequencer
        sequencer.stop()
        //Clear the track
        track?.removeAllEvents()
        //Clear the tweets list
        clearAllTweets()
        //lastTimeStamp = 0
        lastTimeStamp = NSDate()
        tweetsProcessed = 0
        eventsProcessed = 0
        firstTimeStamp = NSDate()
        //create the new request
        request = client!.streaming("https://stream.twitter.com/1.1/statuses/filter.json",
            parameters: ["track": string])
            .progress(progressHandler).completion(completionHandler).start()
    }
    
    //UI search bar delegate
    func searchBarTextDidEndEditing(searchBar: UISearchBar) {
        let newVal = searchBar.text!
        trackTwitterString(newVal)
    }
    
    func searchBarShouldEndEditing(searchBar: UISearchBar) -> Bool {
        return true
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        searchBar.endEditing(true)
    }
    
    //Override tweet view default behavior to launch safari for item tapped
    func tweetView(tweetView: TWTRTweetView, didSelectTweet tweet: TWTRTweet) {
        return
    }
    func tweetView(tweetView: TWTRTweetView, didTapImage image: UIImage, withURL imageURL: NSURL) {
        return
    }
    func tweetView(tweetView: TWTRTweetView, didTapProfileImageForUser user: TWTRUser) {
        return
    }
    func tweetView(tweetView: TWTRTweetView, didTapURL url: NSURL) {
        return
    }
    func tweetView(tweetView: TWTRTweetView, didTapVideoWithURL videoURL: NSURL) {
        return
    }

}

