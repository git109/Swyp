//
//  swypWorkspaceViewController.m
//  swyp
//
//  Created by Alexander List on 7/27/11.
//  Copyright 2011 ExoMachina. Some rights reserved -- see included 'license' file.
//

#import "swypWorkspaceViewController.h"
#import "swypInGestureRecognizer.h"
#import "swypOutGestureRecognizer.h"

#import "swypWorkspaceBackgroundView.h"

@implementation swypWorkspaceViewController
@synthesize workspaceID = _workspaceID, connectionManager = _connectionManager, contentManager = _contentManager, showContentWithoutConnection = _showContentWithoutConnection, worspaceDelegate = _worspaceDelegate;

#pragma mark -
#pragma mark swypConnectionManagerDelegate
-(swypConnectionManager*)	connectionManager{
	if (_connectionManager == nil){
		_connectionManager = [[swypConnectionManager alloc] init];
		[_connectionManager setDelegate:self];
	}
	
	return _connectionManager;
}

-(void)	swypConnectionSessionWasCreated:(swypConnectionSession*)session		withConnectionManager:(swypConnectionManager*)manager{
	
	swypSessionViewController * sessionViewController	= [[swypSessionViewController alloc] initWithConnectionSession:session];
	[sessionViewController.view setCenter:[[[session representedCandidate] matchedLocalSwypInfo]endPoint]];
	[self.view addSubview:sessionViewController.view];
	[self.view setBackgroundColor:[[session sessionHueColor] colorWithAlphaComponent:.4]];
	[[self contentManager] maintainSwypSessionViewController:sessionViewController];
	SRELS(sessionViewController);
	
	
	UIView *swypBeginningContentView	=	[[[session representedCandidate] matchedLocalSwypInfo] swypBeginningContentView];
#pragma mark CLUDGE!
#warning CLUDGE!
	NSBlockOperation *	contentSwypOp	=	[NSBlockOperation blockOperationWithBlock:^{
		if (swypBeginningContentView != nil && [[_contentManager contentDisplayController] respondsToSelector:@selector(contentIndexMatchingSwypOutView:)]){
			NSInteger swypOutContentIndex	=	[[_contentManager contentDisplayController] contentIndexMatchingSwypOutView:swypBeginningContentView];
			if (swypOutContentIndex > -1){
				EXOLog(@"Sending 'contentSwyp' content at index: %i", swypOutContentIndex );
				[_contentManager sendContentAtIndex:swypOutContentIndex throughConnectionSession:session];
				[[_contentManager contentDisplayController] returnContentAtIndexToNormalLocation:swypOutContentIndex animated:TRUE];
			}
		}		
	}];
	
	[NSTimer scheduledTimerWithTimeInterval:.2 target:contentSwypOp selector:@selector(start) userInfo:nil repeats:NO];
		
}
-(void)	swypConnectionSessionWasInvalidated:(swypConnectionSession*)session	withConnectionManager:(swypConnectionManager*)manager error:(NSError*)error{
	
}
#pragma mark -
#pragma mark public
-(swypContentInteractionManager*)	contentManager{
	if (_contentManager == nil){
		_contentManager = [[swypContentInteractionManager alloc] initWithMainWorkspaceView:self.view showingContentBeforeConnection:_showContentWithoutConnection];
		
		//	this is where plainly	[_contentManager initializeInteractionWorkspace]; should be; It's cludged because otherwise contentInteractionController is un-interactable 
		//	So we just run this at the beginning of the next runLoop
		NSBlockOperation * initializeWorkspaceOperation = [NSBlockOperation blockOperationWithBlock:^{
			[[self contentManager] initializeInteractionWorkspace];
		}];
		[[NSOperationQueue mainQueue] addOperation:initializeWorkspaceOperation];
		[[NSOperationQueue mainQueue] setSuspended:FALSE];

	}
	
	return _contentManager;
}

#pragma mark -
#pragma mark workspaceInteraction
-(void)setShowContentWithoutConnection:(BOOL)showContentWithoutConnection{
	_showContentWithoutConnection = showContentWithoutConnection;
	if ((_contentManager != nil || _showContentWithoutConnection == TRUE) && [[self contentManager] showContentBeforeConnection] != showContentWithoutConnection){
		SRELS(_contentManager);
		[self contentManager];
	}
}


#pragma mark -
#pragma mark UIGestureRecognizerDelegate
-(void)	swypInGestureChanged:(swypInGestureRecognizer*)recognizer{
	if (recognizer.state == UIGestureRecognizerStateRecognized){
		[_connectionManager swypInCompletedWithSwypInfoRef:[recognizer swypGestureInfo]];
	}
}

-(void)	swypOutGestureChanged:(swypOutGestureRecognizer*)recognizer{
	if (recognizer.state == UIGestureRecognizerStateBegan){
		[_connectionManager swypOutStartedWithSwypInfoRef:[recognizer swypGestureInfo]];
	}else if (recognizer.state == UIGestureRecognizerStateCancelled){
		[_connectionManager swypOutFailedWithSwypInfoRef:[recognizer swypGestureInfo]];
	}else if (recognizer.state == UIGestureRecognizerStateRecognized){
		[_connectionManager swypOutCompletedWithSwypInfoRef:[recognizer swypGestureInfo]];	
	}
}


-(BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
	
	if ([gestureRecognizer isKindOfClass:[swypGestureRecognizer class]])
		return TRUE;
	
	return FALSE;
}

-(void)	leaveWorkspaceRecognizerChanged: (UITapGestureRecognizer*)recognizer{
	if (recognizer.state == UIGestureRecognizerStateRecognized){
		[_worspaceDelegate delegateShouldDismissSwypWorkspace:self];
	}
}


#pragma mark UIViewController
-(id)	initWithContentWorkspaceID:(NSString*)workspaceID workspaceDelegate:(id<swypWorkspaceDelegate>)	worspaceDelegate{
	if (self = [super initWithNibName:nil bundle:nil]){
		[self setModalPresentationStyle:	UIModalPresentationFullScreen];
		[self setModalTransitionStyle:		UIModalTransitionStyleCrossDissolve];
		
		_worspaceDelegate	=	worspaceDelegate;
	}
	return self;
}
-(void)	viewDidLoad{
	[super viewDidLoad];

	[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:YES];	
	
	swypWorkspaceBackgroundView * backgroundView	= [[swypWorkspaceBackgroundView alloc] initWithFrame:self.view.frame];
	self.view	= backgroundView;
	
	[[self connectionManager] startServices];
	
	swypInGestureRecognizer*	swypInRecognizer	=	[[swypInGestureRecognizer alloc] initWithTarget:self action:@selector(swypInGestureChanged:)];
	[swypInRecognizer setDelegate:self];
	[swypInRecognizer setDelaysTouchesBegan:FALSE];
	[swypInRecognizer setDelaysTouchesEnded:FALSE];
	[swypInRecognizer setCancelsTouchesInView:FALSE];
	[self.view addGestureRecognizer:swypInRecognizer];
	SRELS(swypInRecognizer);

	swypOutGestureRecognizer*	swypOutRecognizer	=	[[swypOutGestureRecognizer alloc] initWithTarget:self action:@selector(swypOutGestureChanged:)];
	[swypOutRecognizer setDelegate:self];
	[swypOutRecognizer setDelaysTouchesBegan:FALSE];
	[swypOutRecognizer setDelaysTouchesEnded:FALSE];
	[swypOutRecognizer setCancelsTouchesInView:FALSE];
	[self.view addGestureRecognizer:swypOutRecognizer];	
	SRELS(swypOutRecognizer);	

	UITapGestureRecognizer * leaveWorkspaceRecognizer	=	[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(leaveWorkspaceRecognizerChanged:)];
	[leaveWorkspaceRecognizer setNumberOfTapsRequired:2];
	[self.view addGestureRecognizer:leaveWorkspaceRecognizer];
	SRELS(leaveWorkspaceRecognizer);
	
}
-(void)	dealloc{
	
	[super dealloc];
}
@end