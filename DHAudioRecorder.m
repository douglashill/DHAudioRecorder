//
//  DHAudioRecorder.m
//  Douglas Hill, February 2014
//  https://github.com/douglashill/DHAudioRecorder
//

#import "DHAudioRecorder.h"

typedef enum {
	DHAudioRecorderStateNotRecordingHaveNothing,
	DHAudioRecorderStateNotRecordingCanPlay,
	DHAudioRecorderStateRecording,
	DHAudioRecorderStatePlaying,
} DHAudioRecorderState;

static NSString * const defaultFilename = @"recording.caf";
static UIControlEvents const triggerEvents = UIControlEventTouchUpInside;

@interface DHAudioRecorder () <AVAudioPlayerDelegate, AVAudioRecorderDelegate>

@end

@implementation DHAudioRecorder
{
	AVAudioRecorder *recorder;
	AVAudioPlayer *player;
}

- (instancetype)init
{
	return [self initWithURL:nil];
}

- (instancetype)initWithURL:(NSURL *)URL
{
	self = [super init];
	if (self == nil) return nil;

    // TODO: Ought to clean up or make it possible to clean up.
	_URL = URL ?: [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:defaultFilename];

	return self;
}

- (instancetype)initWithURL:(NSURL *)URL recordButton:(UIButton *)recordControl playButton:(UIButton *)playControl
{
	self = [self initWithURL:URL];
	if (self == nil) return nil;

	[self setRecordButton:recordControl];
	[self setPlayButton:playControl];

	return self;
}

- (void)setRecordButton:(UIButton *)recordButton
{
	if (recordButton == _recordButton) {
		return;
	}
	
	SEL const action = @selector(toggleRecord:);
	[_recordButton removeTarget:self action:action forControlEvents:triggerEvents];
	[recordButton addTarget:self action:action forControlEvents:triggerEvents];
	
	_recordButton = recordButton;

	[self updateState];
}

- (void)setPlayButton:(UIButton *)playButton
{
	if (playButton == _playButton) {
		return;
	}
	
	SEL const action = @selector(togglePlay:);
	[_playButton removeTarget:self action:action forControlEvents:triggerEvents];
	[playButton addTarget:self action:action forControlEvents:triggerEvents];
	
	_playButton = playButton;

	[self updateState];
}

- (void)updateState {
	if ([[NSFileManager defaultManager] fileExistsAtPath:[[self URL] path]]) {
		[self enterState:DHAudioRecorderStateNotRecordingCanPlay];
		return;
	}

	[self enterState:DHAudioRecorderStateNotRecordingHaveNothing];
}

#pragma mark - Actions

- (IBAction)toggleRecord:(id)sender
{
	if (!recorder) {
		NSError *error = nil;
		recorder = [[AVAudioRecorder alloc] initWithURL:[self URL]
											   settings:@{}
												  error:&error];
		if (error) {
			NSLog(@"Error initialising recorder: %@", [error localizedDescription]);
			return;
		}
		[recorder setDelegate:self];
	}
	
	if ([recorder isRecording]) {
		[recorder stop];
		[self enterState:DHAudioRecorderStateNotRecordingCanPlay];
	}
	else {
		NSError *error;
		if (![[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:&error]) {
			NSLog(@"Could not change audio session category to playback: %@", error);
		}

		BOOL success = [recorder record];
		if (!success) {
			NSLog(@"could not start recording");
			return;
		}
		[self enterState:DHAudioRecorderStateRecording];
	}
}

- (IBAction)togglePlay:(id)sender
{
	if (!player) {
		player = [[AVAudioPlayer alloc] initWithContentsOfURL:[self URL]
														error:nil];
		[player setDelegate:self];
	}
	
	if ([player isPlaying]) {
		[player stop];
		[self enterState:DHAudioRecorderStateNotRecordingCanPlay];
	}
	else {
		NSError *error;
		if (![[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error]) {
			NSLog(@"Could not change audio session category to playback: %@", error);
		}
		BOOL const success = [player play];
		if (!success) {
			NSLog(@"Could not start playback.");
			return;
		}
		[self enterState:DHAudioRecorderStatePlaying];
	}
}

#pragma mark -

- (void)enterState:(DHAudioRecorderState)newState
{
	// start from inital state of not recording, can not play
	[[self recordButton] setEnabled:YES];
	[[self recordButton] setSelected:NO];
	[[self playButton] setEnabled:NO];
	[[self playButton] setSelected:NO];
	
	// alter as appropriate for the target state
	switch (newState) {
		case DHAudioRecorderStateRecording:
			[[self recordButton] setSelected:YES];
			break;
		case DHAudioRecorderStateNotRecordingCanPlay:
			[[self playButton] setEnabled:YES];
			break;
		case DHAudioRecorderStatePlaying:
			[[self recordButton] setEnabled:NO];
			[[self playButton] setEnabled:YES];
			[[self playButton] setSelected:YES];
			break;	
		default:
			break;
	}
}

#pragma mark - AVAudioRecorderDelegate

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {
	NSLog(@"Recorder encode error: %@", error);
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)aPlayer
					   successfully:(BOOL)sucessful
{
	if (!sucessful) {
		NSLog(@"Playing ended, but not sucessfully");
	}
	[self enterState:DHAudioRecorderStateNotRecordingCanPlay];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)aPlayer
								 error:(NSError *)anError
{
	NSLog(@"Player decoding error: %@", [anError localizedDescription]);
}


@end
