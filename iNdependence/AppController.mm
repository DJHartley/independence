/*
 *  AppController.mm
 *  iNdependence
 *
 *  Created by The Operator on 23/08/07.
 *  Copyright 2007 The Operator. All rights reserved.
 *
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License version 2, as published by the Free Software Foundation.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * See the GNU General Public License version 2 for more details
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
//#include <openssl/md5.h>

#import "AppController.h"
#import "MainWindow.h"
#import "SSHHandler.h"
#include "PhoneInteraction/UtilityFunctions.h"
#include "PhoneInteraction/PhoneInteraction.h"
#include "PhoneInteraction/SSHHelper.h"

#define PRE_FIRMWARE_UPGRADE_FILE "/private/var/root/Media/disk"


enum
{
	MENU_ITEM_ACTIVATE = 12,
	MENU_ITEM_DEACTIVATE = 13,
	MENU_ITEM_RETURN_TO_JAIL = 14,
	MENU_ITEM_JAILBREAK = 15,
	MENU_ITEM_PERFORM_SIM_UNLOCK = 16,
	MENU_ITEM_INSTALL_SSH = 17,
	MENU_ITEM_CHANGE_PASSWORD = 18,
	MENU_ITEM_ENTER_RECOVERY_MODE = 19,
	MENU_ITEM_ENTER_DFU_MODE = 20,
	MENU_ITEM_REMOVE_SSH = 21,
	MENU_ITEM_PRE_FIRMWARE_UPGRADE = 22
};

extern MainWindow *g_mainWindow;
static AppController *g_appController;
static PhoneInteraction *g_phoneInteraction;
static bool g_ignoreJailbreakSuccess;

static void updateStatus(const char *msg, bool waiting)
{
	
	if (g_mainWindow) {
		[g_mainWindow setStatus:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding] spinning:waiting];
	}
	
}

static void phoneInteractionNotification(int type, const char *msg)
{
	
	if (g_mainWindow) {
		
		switch (type) {
			case NOTIFY_CONNECTED:
				[g_appController setConnected:true];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_DISCONNECTED:
				[g_appController setConnected:false];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_AFC_CONNECTED:
				[g_appController setAFCConnected:true];
				break;
			case NOTIFY_AFC_DISCONNECTED:
				[g_appController setAFCConnected:false];
				break;
			case NOTIFY_INITIALIZATION_FAILED:
				[g_mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				[NSApp terminate:g_appController];
				break;
			case NOTIFY_INITIALIZATION_WARNING:
				[g_mainWindow displayAlert:@"Warning" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_CONNECTION_FAILED:
				[g_mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_AFC_CONNECTION_FAILED:
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_ACTIVATION_SUCCESS:
				[g_appController setActivated:g_phoneInteraction->isPhoneActivated()];
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Success" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_DEACTIVATION_SUCCESS:
				[g_appController setActivated:g_phoneInteraction->isPhoneActivated()];
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Success" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_JAILBREAK_SUCCESS:

				if (!g_ignoreJailbreakSuccess) {
					[g_mainWindow endDisplayWaitingSheet];
				}

				[g_appController setPerformingJailbreak:false];
				[g_appController setJailbroken:g_phoneInteraction->isPhoneJailbroken()];
				[g_mainWindow updateStatus];

				if ([g_appController isWaitingForActivation]) {
					[g_appController activateStageTwo:true];
				}
				else if ([g_appController isWaitingForDeactivation]) {
					[g_appController deactivateStageTwo];
				}
				else if (g_ignoreJailbreakSuccess) {
					g_ignoreJailbreakSuccess = false;
				}
				else {
					[g_mainWindow displayAlert:@"Success" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				}

				break;
			case NOTIFY_JAILRETURN_SUCCESS:
				[g_mainWindow endDisplayWaitingSheet];
				[g_appController setReturningToJail:false];
				[g_appController setJailbroken:g_phoneInteraction->isPhoneJailbroken()];
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Success" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_SIMUNLOCK_SUCCESS:
				[g_mainWindow endDisplayWaitingSheet];
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Success" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_DFU_SUCCESS:
				[g_mainWindow endDisplayWaitingSheet];
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Success" message:@"Your phone is now in DFU mode and is ready for you to downgrade."];
				break;
			case NOTIFY_JAILBREAK_FAILED:
				[g_mainWindow endDisplayWaitingSheet];
				[g_appController setPerformingJailbreak:false];
				[g_appController setJailbroken:g_phoneInteraction->isPhoneJailbroken()];
				[g_mainWindow updateStatus];

				if ([g_appController isWaitingForActivation]) {
					[g_appController activationFailed:msg];
				}
				else if ([g_appController isWaitingForDeactivation]) {
					[g_appController deactivationFailed:msg];
				}
				else {
					[g_mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				}

				break;
			case NOTIFY_JAILRETURN_FAILED:
				[g_mainWindow endDisplayWaitingSheet];
				[g_appController setReturningToJail:false];
				[g_appController setJailbroken:g_phoneInteraction->isPhoneJailbroken()];
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_SIMUNLOCK_FAILED:
				[g_mainWindow endDisplayWaitingSheet];
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_DFU_FAILED:
				[g_mainWindow endDisplayWaitingSheet];
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_ACTIVATION_FAILED:
			case NOTIFY_DEACTIVATION_FAILED:
				[g_appController setActivated:g_phoneInteraction->isPhoneActivated()];
			case NOTIFY_PUTSERVICES_FAILED:
			case NOTIFY_PUTFSTAB_FAILED:
			case NOTIFY_PUTPEM_FAILED:
			case NOTIFY_GET_ACTIVATION_FAILED:
			case NOTIFY_PUTFILE_FAILED:
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_GET_ACTIVATION_SUCCESS:
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Success" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_112_JAILBREAK_STAGE_ONE_WAIT:
				[g_mainWindow endDisplayWaitingSheet];
				[g_mainWindow startDisplayWaitingSheet:nil
											   message:@"Please press and hold the Sleep/Wake button for 3 seconds, then power off your phone, then press Sleep/Wake again to restart it."
												 image:[NSImage imageNamed:@"sleep_button"] cancelButton:false runModal:false];
				break;
			case NOTIFY_112_JAILBREAK_STAGE_TWO_WAIT:
				[g_mainWindow endDisplayWaitingSheet];

				if ([g_appController isWaitingForActivation]) {
					[g_appController activateStageTwo:false];
				}

				[g_mainWindow startDisplayWaitingSheet:nil
											   message:@"Please reboot your phone again using the same steps..."
												 image:[NSImage imageNamed:@"sleep_button"] cancelButton:false runModal:false];
				break;
			case NOTIFY_113_JAILBREAK_STAGE_TWO_WAIT:
				updateStatus(msg, true);
				break;
			case NOTIFY_SIMUNLOCK_STAGE_TWO_WAIT:
				updateStatus(msg, true);
				break;
			case NOTIFY_JAILBREAK_RECOVERY_WAIT:
				[g_mainWindow startDisplayWaitingSheet:nil message:@"Waiting for jail break..." image:[NSImage imageNamed:@"jailbreak"] cancelButton:false runModal:false];
				break;
			case NOTIFY_JAILRETURN_RECOVERY_WAIT:
				[g_mainWindow startDisplayWaitingSheet:nil message:@"Waiting for return to jail..." image:[NSImage imageNamed:@"jailbreak"] cancelButton:false runModal:false];
				break;
			case NOTIFY_SIMUNLOCK_RECOVERY_WAIT:
				[g_mainWindow startDisplayWaitingSheet:nil message:@"Waiting for SIM unlock..." image:nil cancelButton:false runModal:false];
				break;
			case NOTIFY_DFU_RECOVERY_WAIT:
				[g_mainWindow startDisplayWaitingSheet:nil message:@"Waiting to enter DFU mode..." image:nil cancelButton:false runModal:false];
				break;
			case NOTIFY_RECOVERY_CONNECTED:
				[g_appController setRecoveryMode:true];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_RECOVERY_DISCONNECTED:
				[g_appController setRecoveryMode:false];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_RECOVERY_FAILED:
				[g_mainWindow endDisplayWaitingSheet];
				[g_mainWindow updateStatus];
				[g_mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
				break;
			case NOTIFY_RESTORE_CONNECTED:
				[g_appController setRestoreMode:true];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_RESTORE_DISCONNECTED:
				[g_appController setRestoreMode:false];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_DFU_CONNECTED:
				[g_appController setDFUMode:true];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_DFU_DISCONNECTED:
				[g_appController setDFUMode:false];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_JAILBREAK_CANCEL:
				[g_mainWindow endDisplayWaitingSheet];
				[g_mainWindow updateStatus];
				break;
			case NOTIFY_CONNECTION_SUCCESS:
			case NOTIFY_AFC_CONNECTION_SUCCESS:
			case NOTIFY_INITIALIZATION_SUCCESS:
			case NOTIFY_PUTFSTAB_SUCCESS:
			case NOTIFY_PUTSERVICES_SUCCESS:
			case NOTIFY_PUTPEM_SUCCESS:
			default:
				break;
		}
		
	}
	
}

@implementation AppController

- (void)dealloc
{
	
	if (m_phoneInteraction != NULL) {
		delete m_phoneInteraction;
	}

	if (m_sshPath != NULL) {
		free(m_sshPath);
	}

	if (m_ramdiskPath != nil) {
		[m_ramdiskPath release];
		m_ramdiskPath = nil;
	}

	[super dealloc];
}

- (void)awakeFromNib
{
	g_appController = self;

	if (!g_mainWindow) {
		g_mainWindow = mainWindow;
	}

	g_ignoreJailbreakSuccess = false;
	m_connected = false;
	m_afcConnected = false;
	m_recoveryMode = false;
	m_restoreMode = false;
	m_dfuMode = false;
	m_jailbroken = false;
	m_activated = false;
	m_performingJailbreak = false;
	m_returningToJail = false;
	m_installingSSH = false;
	m_waitingForActivation = false;
	m_waitingForDeactivation = false;
	m_waitingForNewActivation = false;
	m_waitingForNewDeactivation = false;
	m_waitingForRecoveryModeSwitch = false;
	m_bootCount = 0;
	m_sshPath = NULL;
	m_ramdiskPath = nil;
	m_rdFirmwarePath = nil;
	m_rdDLPath = nil;
	m_downloadResponse = nil;
	[customizeBrowser setEnabled:NO];
	m_phoneInteraction = PhoneInteraction::getInstance(updateStatus, phoneInteractionNotification);
	g_phoneInteraction = m_phoneInteraction;
}

// -----------------------------------------------------------------------------------

- (NSString*)pathToAppSupportRamDisk
{
	// find the path to ~/Library/Application Support/
	FSRef foundRef;
	OSErr err = FSFindFolder(kUserDomain, kApplicationSupportFolderType, kDontCreateFolder, &foundRef);
	
	if (err != noErr) {
		return nil;
	}
	
	unsigned char path[PATH_MAX];
	FSRefMakePath(&foundRef, path, sizeof(path));
	NSString *applicationSupportFolder = [NSString stringWithUTF8String:(const char*)path];
	
	if (applicationSupportFolder == nil) {
		return nil;
	}
	
	applicationSupportFolder = [applicationSupportFolder stringByAppendingPathComponent:@"iNdependence/"];

	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDir = NO;

	if (![fm fileExistsAtPath:applicationSupportFolder isDirectory:&isDir]) {

		if (![fm createDirectoryAtPath:applicationSupportFolder attributes:nil]) {
			return nil;
		}

	}
	else if (!isDir) {

		if (![fm removeFileAtPath:applicationSupportFolder handler:nil]) {
			return nil;
		}

		if (![fm createDirectoryAtPath:applicationSupportFolder attributes:nil]) {
			return nil;
		}

	}

	// remove any old versions of the RAM disk
	int i;
	NSString *oldFile;

	for (int i = 1; i < 2; i++) {
		oldFile = [applicationSupportFolder stringByAppendingPathComponent:[NSString stringWithFormat:@"ramit112_%d.dat", i]];

		if ([fm fileExistsAtPath:oldFile]) {
			[fm removeFileAtPath:oldFile handler:nil];
		}

	}

	return [applicationSupportFolder stringByAppendingPathComponent:@"ramit112_2.dat"];
}

- (NSString*)generateRamdisk
{
	NSFileManager *fileManager = [NSFileManager defaultManager];

	if (m_rdFirmwarePath == nil) {
		NSString *homeDir = NSHomeDirectory();

		if (homeDir == nil) {
			[mainWindow displayAlert:@"Error" message:@"Couldn't get home directory."];
			return nil;
		}

		m_rdDLPath = [homeDir stringByAppendingPathComponent:@"Library/iTunes/iPhone Software Updates/"];

		if (![fileManager fileExistsAtPath:m_rdDLPath]) {

			if (![fileManager createDirectoryAtPath:m_rdDLPath attributes:nil]) {
				return nil;
			}

		}
		
		m_rdFirmwarePath = [m_rdDLPath stringByAppendingPathComponent:@"iPhone1,1_1.1.2_3B48b_Restore.ipsw"];
		[m_rdDLPath retain];
		[m_rdFirmwarePath retain];
	}

#ifdef DEBUG
	NSLog(@"Firmware path is: %@", m_rdFirmwarePath);
	NSLog(@"Firmware DL path is: %@", m_rdDLPath);
#endif

	if ( ![[NSFileManager defaultManager] fileExistsAtPath:m_rdFirmwarePath] ) {
		[mainWindow startDisplayWaitingSheet:nil
									 message:@"Downloading firmware file..."
									   image:nil cancelButton:false
							   indeterminate:NO runModal:false];
		[mainWindow updateWaitingSheetPct:0.0];

		m_bIsDownloading = true;
		m_bDownloadSucceeded = false;

		NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPhone/061-4037.20071107.5Bghn/iPhone1,1_1.1.2_3B48b_Restore.ipsw"]];
		NSURLDownload *dl = [[NSURLDownload alloc] initWithRequest:req delegate:self];

		if (dl == nil) {
			[mainWindow endDisplayWaitingSheet];
			[mainWindow displayAlert:@"Error" message:@"Couldn't download firmware file."];
			return nil;
		}

		[dl setDestination:m_rdFirmwarePath allowOverwrite:YES];

		while (m_bIsDownloading) {
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];

			if (m_expectedLength != NSURLResponseUnknownLength) {
				float percentComplete = ((float)m_bytesReceived / (float)m_expectedLength) * 100.0f;
				[mainWindow updateWaitingSheetPct:percentComplete];
			}
			else {
				[mainWindow updateWaitingSheetPct:-1.0f];
			}

		}

		if (m_bDownloadSucceeded) {
			[mainWindow updateWaitingSheetPct:100.0];
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
		}

		[mainWindow endDisplayWaitingSheet];

		if (m_downloadResponse) {
			[m_downloadResponse release];
			m_downloadResponse = nil;
		}

		if (!m_bDownloadSucceeded) {
			[mainWindow displayAlert:@"Error" message:@"Couldn't download firmware file."];
			return nil;
		}

	}

	NSFileManager *fm = [NSFileManager defaultManager];

	[mainWindow startDisplayWaitingSheet:nil
								 message:@"Creating RAM disk..."
								   image:nil cancelButton:false
						   indeterminate:NO runModal:false];
	[mainWindow updateWaitingSheetPct:0.0];

	// get paths to the resource files
	NSString *rdExtraFiles = [[NSBundle mainBundle] pathForResource:@"ramit112_files" ofType:@"zip"];
	
	if (rdExtraFiles == nil) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't find extra RAM disk files."];
		return nil;
	}

#ifdef DEBUG
	NSLog(@"Extracting firmware files...");
#endif

	[mainWindow updateWaitingSheetPct:5.0];

	// extract the firmware
	NSString *extractPath = [m_rdDLPath stringByAppendingPathComponent:@"firmware_112/"];

	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/bin/ditto"];
	[task setArguments:[NSArray arrayWithObjects:@"-k", @"-x", m_rdFirmwarePath, extractPath, nil]];
	[task launch];
	[task waitUntilExit];

	if ([task terminationStatus] != 0) {
		[task release];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't extract firmware file contents."];
		return nil;
	}

	[task release];
	[mainWindow updateWaitingSheetPct:25.0];

#ifdef DEBUG
	NSLog(@"Stripping 2048 byte header...");
#endif

	// strip the 2048 byte header from the embedded RAM disk
	NSString *ifFile = [extractPath stringByAppendingPathComponent:@"022-3726-1.dmg"];
	NSString *ofFile = [m_rdDLPath stringByAppendingPathComponent:@"ramdisk.dmg"];

	task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/dd"];
	[task setArguments:[NSArray arrayWithObjects:[NSString stringWithFormat:@"if=%@", ifFile],
						[NSString stringWithFormat:@"of=%@", ofFile], @"bs=512", @"skip=4", @"conv=sync", nil]];
	[task launch];
	[task waitUntilExit];

	if ([task terminationStatus] != 0) {
		[task release];
		[fm removeFileAtPath:extractPath handler:nil];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't strip header from firmware RAM disk."];
		return nil;
	}

	[task release];
	[mainWindow updateWaitingSheetPct:30.0];

#ifdef DEBUG
	NSLog(@"Decrypting RAM disk...");
#endif

	// decrypt the RAM disk
	NSString *decFile = [m_rdDLPath stringByAppendingPathComponent:@"ramdisk_decrypted.dmg"];

	task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/bin/openssl"];
	[task setArguments:[NSArray arrayWithObjects:@"enc", @"-d", @"-in", ofFile, @"-out",
						decFile, @"-aes-128-cbc", @"-K", @"188458A6D15034DFE386F23B61D43774",
						@"-iv", @"0", nil]];
	[task launch];
	[task waitUntilExit];

	// 0p - Ignore the failure in this case
	/*
	if ([task terminationStatus] != 0) {
		[task release];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't decrypt firmware RAM disk."];
		return nil;
	}
	 */

	[task release];
	[mainWindow updateWaitingSheetPct:40.0];

#ifdef DEBUG
	NSLog(@"Stripping the RAM disk signature...");
#endif

	// now strip the signature from the decrypted RAM disk
	NSString *decCleanFile = [m_rdDLPath stringByAppendingPathComponent:@"ramdisk_decrypted_clean.dmg"];

	task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/dd"];
	[task setArguments:[NSArray arrayWithObjects:[NSString stringWithFormat:@"if=%@", decFile],
						[NSString stringWithFormat:@"of=%@", decCleanFile], @"bs=512", @"count=36632", @"conv=sync", nil]];
	[task launch];
	[task waitUntilExit];
	
	if ([task terminationStatus] != 0) {
		[task release];
		[fm removeFileAtPath:extractPath handler:nil];
		[fm removeFileAtPath:ofFile handler:nil];
		[fm removeFileAtPath:decFile handler:nil];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't strip signature from the decrypted firmware RAM disk."];
		return nil;
	}

	[task release];
	[mainWindow updateWaitingSheetPct:45.0];

#ifdef DEBUG
	NSLog(@"Cleaning up...");
#endif

	// clean up
	if ([fm removeFileAtPath:extractPath handler:nil] == NO) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't clean up firmware path."];
		return nil;
	}

	if ([fm removeFileAtPath:ofFile handler:nil] == NO) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't clean up RAM disk."];
		return nil;
	}

	if ([fm removeFileAtPath:decFile handler:nil] == NO) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't clean up decrypted RAM disk."];
		return nil;
	}

	[mainWindow updateWaitingSheetPct:50.0];

#ifdef DEBUG
	NSLog(@"Mounting the RAM disk...");
#endif

	// mount the RAM disk
	task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/bin/hdiutil"];
	[task setArguments:[NSArray arrayWithObjects:@"attach", decCleanFile, nil]];

	NSPipe *output = [NSPipe pipe];
	[task setStandardOutput:output];
	[task launch];
	[task waitUntilExit];

	if ([task terminationStatus] != 0) {
		[task release];
		[fm removeFileAtPath:decCleanFile handler:nil];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't mount decrypted, cleaned firmware RAM disk."];
		return nil;
	}

	// scan the output of hdiutil for the RAM disk mount point
	NSString *mountPoint = @"/Volumes/ramdisk";
    NSData *outputData = [[output fileHandleForReading] readDataToEndOfFile];
    NSString *outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
	NSRange range = [outputString rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	if (range.location != NSNotFound) {
		NSString *newString = [outputString substringFromIndex:range.location];

		if (newString != nil) {
			range = [newString rangeOfString:@"/"];

			if (range.location != NSNotFound) {
				newString = [newString substringFromIndex:range.location];

				if (newString != nil) {
					newString = [newString stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r"]];
					mountPoint = [NSString stringWithString:newString];
				}

			}

		}

	}

#ifdef DEBUG
	NSLog(@"Mount point is: %@", mountPoint);
#endif

	[task release];
	[outputString release];
	[mainWindow updateWaitingSheetPct:65.0];

#ifdef DEBUG
	NSLog(@"Modifying the RAM disk...");
#endif

	// modify the RAM disk
	NSString *rmDir = [mountPoint stringByAppendingPathComponent:@"System/Library/Frameworks/CoreGraphics.framework"];

	if ([fm removeFileAtPath:rmDir handler:nil] == NO) {
		task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/bin/hdiutil"];
		[task setArguments:[NSArray arrayWithObjects:@"detach", mountPoint, nil]];
		[task launch];
		[task waitUntilExit];
		[task release];
		[fm removeFileAtPath:decCleanFile handler:nil];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't modify RAM disk."];
		return nil;
	}

	[mainWindow updateWaitingSheetPct:70.0];

	task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/bin/ditto"];
	[task setArguments:[NSArray arrayWithObjects:@"-k", @"-x", rdExtraFiles, mountPoint, nil]];
	[task launch];
	[task waitUntilExit];
	
	if ([task terminationStatus] != 0) {
		[task release];
		task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/bin/hdiutil"];
		[task setArguments:[NSArray arrayWithObjects:@"detach", mountPoint, nil]];
		[task launch];
		[task waitUntilExit];
		[task release];
		[fm removeFileAtPath:decCleanFile handler:nil];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't decompress extra files to the RAM disk."];
		return nil;
	}

	[task release];
	[mainWindow updateWaitingSheetPct:75.0];

#ifdef DEBUG
	NSLog(@"Unmounting the RAM disk...");
#endif

	// unmount the RAM disk
	task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/bin/hdiutil"];
	[task setArguments:[NSArray arrayWithObjects:@"detach", mountPoint, nil]];
	[task launch];
	[task waitUntilExit];
	
	if ([task terminationStatus] != 0) {
		[task release];
		[fm removeFileAtPath:decCleanFile handler:nil];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't unmount firmware RAM disk."];
		return nil;
	}

	[task release];
	[mainWindow updateWaitingSheetPct:85.0];

#ifdef DEBUG
	NSLog(@"Creating new RAM disk...");
#endif

	// create the new RAM disk
	unsigned int dataLength = 13377536;
	unsigned char *zData = (unsigned char*)malloc(dataLength);
	bzero(zData, dataLength);
	NSData *zeroData = [NSData dataWithBytes:zData length:dataLength];

	if (zeroData == nil) {
		free(zData);
		[fm removeFileAtPath:decCleanFile handler:nil];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't create zero data for new RAM disk."];
		return nil;
	}

	free(zData);
	NSData *rdData = [NSData dataWithContentsOfFile:decCleanFile];

	if (rdData == nil) {
		[fm removeFileAtPath:decCleanFile handler:nil];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't read in RAM disk image."];
		return nil;
	}

	NSString *newRamDisk = [self pathToAppSupportRamDisk];

	if (newRamDisk == nil) {
		[fm removeFileAtPath:decCleanFile handler:nil];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't get path to RAM disk."];
		return nil;
	}

	int fd = open([newRamDisk UTF8String], O_WRONLY | O_CREAT);

	if (fd == -1) {
		[fm removeFileAtPath:decCleanFile handler:nil];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't create new RAM disk image."];
		return nil;
	}

	// set the proper file attributes
	if (fchmod(fd, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH) == -1) {
		close(fd);
		[fm removeFileAtPath:decCleanFile handler:nil];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't create new RAM disk image."];
		return nil;
	}

	NSFileHandle *rdFH = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];

	if (rdFH == nil) {
		close(fd);
		[fm removeFileAtPath:decCleanFile handler:nil];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't create new RAM disk image."];
		return nil;
	}

	[rdFH writeData:zeroData];
	[rdFH writeData:rdData];
	[rdFH closeFile];
	[rdFH release];

	[mainWindow updateWaitingSheetPct:95.0];

#ifdef DEBUG
	NSLog(@"Secondary clean up...");
#endif

	// clean up again
	if ([fm removeFileAtPath:decCleanFile handler:nil] == NO) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Couldn't clean up decrypted, cleaned RAM disk file."];
		return nil;
	}

	[mainWindow updateWaitingSheetPct:100.0];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	[mainWindow endDisplayWaitingSheet];

	return newRamDisk;
}

- (void)setDownloadResponse:(NSURLResponse*)downloadResponse
{
    [downloadResponse retain];

	if (m_downloadResponse) {
		[m_downloadResponse release];
	}

    m_downloadResponse = downloadResponse;
    m_expectedLength = [downloadResponse expectedContentLength];
}

- (void)download:(NSURLDownload*)download didReceiveResponse:(NSURLResponse*)response
{
	m_bytesReceived = 0;
	[self setDownloadResponse:response];
}

- (void)download:(NSURLDownload*)download didReceiveDataOfLength:(unsigned)length
{
	m_bytesReceived = m_bytesReceived + length;

#ifdef DEBUG
	NSLog(@"Bytes received: %d", m_bytesReceived);
#endif

}

- (void)download:(NSURLDownload*)download didFailWithError:(NSError*)error
{
#ifdef DEBUG
	NSLog(@"download failed");
#endif
	[download release];
	m_bDownloadSucceeded = false;
	m_bIsDownloading = false;
}

#ifdef DEBUG
- (void)downloadDidBegin:(NSURLDownload*)download
{
	NSLog(@"downloadDidBegin");
}
#endif

- (void)downloadDidFinish:(NSURLDownload*)download
{
#ifdef DEBUG
	NSLog(@"downloadDidFinish");
#endif
	[download release];
	m_bDownloadSucceeded = true;
	m_bIsDownloading = false;
}

// -----------------------------------------------------------------------------------

- (bool)validateRamDisk:(NSString*)rdPath
{
	
	// check the MD5 of the RAM disk to ensure it's correct
	//
	// 0p - I wish this worked, but it seems the MD5 is different all the time, so the
	// best we can do is a file size check
	/*
	NSData *checkData = [NSData dataWithContentsOfFile:rdPath];

	if (checkData != nil) {
		unsigned char *digest = (unsigned char*)MD5((const unsigned char*)[checkData bytes], [checkData length], NULL);

		if (digest != NULL) {
			NSString *chkStr = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
								digest[0], digest[1], digest[2], digest[3],
								digest[4], digest[5], digest[6], digest[7],
								digest[8], digest[9], digest[10], digest[11],
								digest[12], digest[13], digest[14], digest[15]];

#ifdef DEBUG
			NSLog(@"RAM disk MD5: %@", chkStr);
#endif

			if ( [chkStr caseInsensitiveCompare:@"2389955b77f2574478609a1460fb4601"] != NSOrderedSame ) {
				return false;
			}
			
		}
		else {
			return false;
		}
		
	}
	else {
		return false;
	}
	 */

	struct stat st;

	if (stat([rdPath UTF8String], &st) == -1) {
		return false;
	}

	if (st.st_size != 32108032) {
		return false;
	}

	return true;
}

- (NSString*)getRamdiskPath
{

	// first see if it's already been initialized
	if (m_ramdiskPath != nil) {

		if ([self validateRamDisk:m_ramdiskPath]) {
			return m_ramdiskPath;
		}
		else {
			[m_ramdiskPath release];
			m_ramdiskPath = nil;
		}

	}

	// now check to see if it's already been generated
	NSString *ramdiskFile = [self pathToAppSupportRamDisk];

	if (ramdiskFile != nil) {

		if ([self validateRamDisk:ramdiskFile]) {
			m_ramdiskPath = [[NSString alloc] initWithString:ramdiskFile];
			return ramdiskFile;
		}
		else {
			[[NSFileManager defaultManager] removeFileAtPath:ramdiskFile handler:nil];
		}

	}

	// ok, looks like we're going to have to generate it
	bool bContinue = true;

	while ( (m_ramdiskPath == nil) && bContinue ) {
		ramdiskFile = [self generateRamdisk];

		if (ramdiskFile != nil) {

			if ([self validateRamDisk:ramdiskFile]) {
				m_ramdiskPath = [[NSString alloc] initWithString:ramdiskFile];
			}

		}

		if (m_ramdiskPath == nil) {
			int retval = NSRunAlertPanel(@"Failed", @"RAM disk creation failed.  Would you like to try again?", @"Yes", @"No", nil);
			
			if (retval != NSAlertDefaultReturn) {
				bContinue = false;
			}
			
		}

	}

	return m_ramdiskPath;
}

- (void)setConnected:(bool)connected
{
	m_connected = connected;
	
	if (m_connected) {
		[self setAFCConnected:m_phoneInteraction->isConnectedToAFC()];
		[self setActivated:m_phoneInteraction->isPhoneActivated()];
		[self setJailbroken:m_phoneInteraction->isPhoneJailbroken()];

		if ([self isAFCConnected]) {

			if ([self isActivated]) {
				[activateButton setEnabled:NO];
				[deactivateButton setEnabled:YES];
			}
			else {
				[activateButton setEnabled:YES];
				[deactivateButton setEnabled:NO];
			}

		}
		else {
			[activateButton setEnabled:NO];
			[deactivateButton setEnabled:NO];
		}

		[enterRecoveryModeButton setEnabled:YES];
		[enterDFUModeButton setEnabled:YES];

		if (m_installingSSH) {
			m_bootCount++;
			[mainWindow endDisplayWaitingSheet];

			if (m_bootCount == 1) {
				[self sshInstallStageTwo];
			}
			else if (m_bootCount == 2) {
				[self sshInstallStageThree];
			}
			else {
				[self finishInstallingSSH:false];
			}

		}
		else if (m_waitingForNewActivation) {
			m_waitingForNewActivation = false;
			[mainWindow endDisplayWaitingSheet];
			[mainWindow displayAlert:@"Success" message:@"Successfully activated phone."];
		}
		else if (m_waitingForNewDeactivation) {
			m_waitingForNewDeactivation = false;
			[mainWindow endDisplayWaitingSheet];
			[mainWindow displayAlert:@"Success" message:@"Successfully deactivated phone."];
		}
		else if (m_waitingForRecoveryModeSwitch) {
			m_waitingForRecoveryModeSwitch = false;
			[mainWindow endDisplayWaitingSheet];
		}

		[performSimUnlockButton setEnabled:YES];
	}
	else {
		[self setAFCConnected:false];
		[self setActivated:false];
		[self setJailbroken:false];

		[activateButton setEnabled:NO];
		[deactivateButton setEnabled:NO];
		[enterRecoveryModeButton setEnabled:NO];
		[enterDFUModeButton setEnabled:NO];
		[performSimUnlockButton setEnabled:NO];
	}
	
	[mainWindow updateStatus];
}

- (bool)isConnected
{
	return m_connected;
}

- (void)setAFCConnected:(bool)connected
{
	m_afcConnected = connected;

	if (m_afcConnected) {

		if ([self isActivated]) {
			[activateButton setEnabled:NO];
			[deactivateButton setEnabled:YES];
		}
		else {
			[activateButton setEnabled:YES];
			[deactivateButton setEnabled:NO];
		}

		if ([self isJailbroken]) {
			[jailbreakButton setEnabled:NO];
			[returnToJailButton setEnabled:YES];
		}
		else {
			[jailbreakButton setEnabled:YES];
			[returnToJailButton setEnabled:NO];
		}
		
	}
	else {
		[activateButton setEnabled:NO];
		[deactivateButton setEnabled:NO];
		[jailbreakButton setEnabled:NO];
		[returnToJailButton setEnabled:NO];
	}

	[mainWindow updateStatus];
}

- (bool)isAFCConnected
{
	return m_afcConnected;
}

- (void)setRecoveryMode:(bool)inRecovery
{
	m_recoveryMode = inRecovery;

	if (m_recoveryMode) {
		[enterRecoveryModeButton setTitle:@"Exit Recovery Mode"];
		[enterRecoveryModeButton setEnabled:YES];
		[enterRecoveryModeDescription setStringValue:@"Returns your phone back to normal mode"];

		if (m_waitingForRecoveryModeSwitch) {
			m_waitingForRecoveryModeSwitch = false;
			[mainWindow endDisplayWaitingSheet];
		}

	}
	else {
		[enterRecoveryModeButton setTitle:@"Enter Recovery Mode"];
		[enterRecoveryModeButton setEnabled:NO];
		[enterRecoveryModeDescription setStringValue:@"Puts your phone into a mode where you can restore the firmware from iTunes without needing activation"];
	}

	[mainWindow updateStatus];
}

- (bool)isInRecoveryMode
{
	return m_recoveryMode;
}

- (void)setRestoreMode:(bool)inRestore
{
	m_restoreMode = inRestore;
	[mainWindow updateStatus];
}

- (bool)isInRestoreMode
{
	return m_restoreMode;
}

- (void)setDFUMode:(bool)inDFU
{
	m_dfuMode = inDFU;
	[mainWindow updateStatus];
}

- (bool)isInDFUMode
{
	return m_dfuMode;
}

- (void)setJailbroken:(bool)jailbroken
{
	m_jailbroken = jailbroken;
	
	if (m_jailbroken) {
		[returnToJailButton setEnabled:YES];
		[customizeBrowser setEnabled:YES];
		[changePasswordButton setEnabled:YES];
		[jailbreakButton setEnabled:NO];

		if ([self isSSHInstalled]) {
			[installSSHButton setEnabled:NO];
			[removeSSHButton setEnabled:YES];

			if (!m_phoneInteraction->fileExists(PRE_FIRMWARE_UPGRADE_FILE)) {
				[preFirmwareUpgradeButton setEnabled:YES];
			}
			else {
				[preFirmwareUpgradeButton setEnabled:NO];
			}

		}
		else {
			[installSSHButton setEnabled:YES];
			[removeSSHButton setEnabled:NO];
			[preFirmwareUpgradeButton setEnabled:NO];
		}

	}
	else {
		[returnToJailButton setEnabled:NO];
		[installSSHButton setEnabled:NO];
		[removeSSHButton setEnabled:NO];
		[changePasswordButton setEnabled:NO];
		[customizeBrowser setEnabled:NO];
		[preFirmwareUpgradeButton setEnabled:NO];

		if ([self isConnected] && [self isAFCConnected]) {
			[jailbreakButton setEnabled:YES];
		}
		else {
			[jailbreakButton setEnabled:NO];
		}

	}
	
	[mainWindow updateStatus];
}

- (bool)isJailbroken
{
	return m_jailbroken;
}

- (void)setActivated:(bool)activated
{
	m_activated = activated;

	if (m_activated) {

		if ([self isJailbroken]) {
			[activateButton setEnabled:NO];
			[deactivateButton setEnabled:YES];
		}

	}
	else {

		if ([self isJailbroken]) {
			[activateButton setEnabled:YES];
			[deactivateButton setEnabled:NO];
		}

	}

	[mainWindow updateStatus];
}

- (bool)isActivated
{
	return m_activated;
}

- (bool)isOpenSSHInstalled
{
	return ( m_phoneInteraction->fileExists("/usr/sbin/sshd") ||
			 m_phoneInteraction->fileExists("/usr/bin/sshd") );
}

- (bool)isDropbearSSHInstalled
{
	return m_phoneInteraction->fileExists("/usr/bin/dropbear");
}

- (bool)isSSHInstalled
{
	return ([self isOpenSSHInstalled] || [self isDropbearSSHInstalled]);
}

- (NSString*)phoneFirmwareVersion
{

	if (m_phoneInteraction->getPhoneProductVersion() == NULL) {
		return @"-";
	}

	return [NSString stringWithCString:m_phoneInteraction->getPhoneProductVersion() encoding:NSUTF8StringEncoding];
}

- (void)setPerformingJailbreak:(bool)bJailbreaking
{
	m_performingJailbreak = bJailbreaking;
}

- (void)setReturningToJail:(bool)bReturning
{
	m_returningToJail = bReturning;
}

- (bool)isWaitingForActivation
{
	return m_waitingForActivation;
}

- (bool)isWaitingForNewActivation
{
	return m_waitingForNewActivation;
}

- (bool)isWaitingForDeactivation
{
	return m_waitingForDeactivation;
}

- (IBAction)performJailbreak:(id)sender
{
	char *value = m_phoneInteraction->getPhoneProductVersion();
	
	if (!strncmp(value, "1.0", 3)) {
		NSString *firmwarePath = nil;

		// first things first -- get the path to the unzipped firmware files
		NSOpenPanel *firmwareOpener = [NSOpenPanel openPanel];
		[firmwareOpener setTitle:@"Select where you unzipped the firmware files"];
		[firmwareOpener setCanChooseDirectories:YES];
		[firmwareOpener setCanChooseFiles:NO];
		[firmwareOpener setAllowsMultipleSelection:NO];

		while (1) {

			if ([firmwareOpener runModalForTypes:nil] != NSOKButton) {
				return;
			}

			firmwarePath = [firmwareOpener filename];

			if ([[NSFileManager defaultManager] fileExistsAtPath:[firmwarePath stringByAppendingString:@"/Restore.plist"]]) {
				break;
			}

			[mainWindow displayAlert:@"Error" message:@"Specified path does not contain firmware files.  Try again."];
			return;
		}

		NSString *servicesFile = [[NSBundle mainBundle] pathForResource:@"Services_mod" ofType:@"plist"];
	
		if (servicesFile == nil) {
			[mainWindow displayAlert:@"Error" message:@"Error finding modified Services.plist file."];
			return;
		}

		NSString *fstabFile = [[NSBundle mainBundle] pathForResource:@"fstab_mod" ofType:@""];
		
		if (fstabFile == nil) {
			[mainWindow displayAlert:@"Error" message:@"Error finding modified fstab file."];
			return;
		}

		m_performingJailbreak = true;
		m_phoneInteraction->performJailbreak(false, [firmwarePath UTF8String], [fstabFile UTF8String],
											 [servicesFile UTF8String]);
	}
	else if (!strncmp(value, "1.1.1", 5) || !strncmp(value, "1.1.2", 5)) {
		NSString *servicesFile = [[NSBundle mainBundle] pathForResource:@"Services111_mod" ofType:@"plist"];
		
		if (servicesFile == nil) {
			[mainWindow displayAlert:@"Error" message:@"Error finding modified Services.plist file."];
			return;
		}
		
		m_performingJailbreak = true;
		m_phoneInteraction->performJailbreak(false, [servicesFile UTF8String]);
	}
	else {
		NSString *ramdiskFile = [self getRamdiskPath];

		if (ramdiskFile == nil) {
			[mainWindow displayAlert:@"Error" message:@"Error obtaining RAM disk file."];
			return;
		}

		m_phoneInteraction->performJailbreak(false, [ramdiskFile UTF8String]);
	}

}

- (IBAction)returnToJail:(id)sender
{
	[mainWindow setStatus:@"Returning to jail..." spinning:true];

	NSString *servicesFile = nil;
	NSString *fstabFile = nil;

	char *value = m_phoneInteraction->getPhoneProductVersion();
	
	if (!strncmp(value, "1.0", 3)) {
		servicesFile = [[NSBundle mainBundle] pathForResource:@"Services" ofType:@"plist"];
		fstabFile = [[NSBundle mainBundle] pathForResource:@"fstab" ofType:@""];
	}
	else if (!strncmp(value, "1.1.1", 5) || !strncmp(value, "1.1.2", 5)) {
		servicesFile = [[NSBundle mainBundle] pathForResource:@"Services111" ofType:@"plist"];
		fstabFile = [[NSBundle mainBundle] pathForResource:@"fstab" ofType:@""];
	}
	else {
		servicesFile = [[NSBundle mainBundle] pathForResource:@"Services113" ofType:@"plist"];
		fstabFile = [[NSBundle mainBundle] pathForResource:@"fstab113" ofType:@""];
	}

	if (servicesFile == nil) {
		[mainWindow displayAlert:@"Error" message:@"Error finding Services.plist file."];
		[mainWindow updateStatus];
		return;
	}

	if (fstabFile == nil) {
		[mainWindow displayAlert:@"Error" message:@"Error finding fstab file."];
		[mainWindow updateStatus];
		return;
	}

	m_returningToJail = true;
	m_phoneInteraction->returnToJail([servicesFile UTF8String], [fstabFile UTF8String]);
}

- (IBAction)enterRecoveryMode:(id)sender
{
	m_waitingForRecoveryModeSwitch = true;

	if ([self isInRecoveryMode]) {
		[mainWindow startDisplayWaitingSheet:@"Returning to normal mode" message:@"Returning to normal mode..." image:nil
								cancelButton:false runModal:false];
		m_phoneInteraction->exitRecoveryMode();
	}
	else {
		[mainWindow startDisplayWaitingSheet:@"Entering recovery mode" message:@"Entering recovery mode..." image:nil
								cancelButton:false runModal:false];
		m_phoneInteraction->enterRecoveryMode();
	}

}

- (IBAction)enterDFUMode:(id)sender
{
	NSString *firmwarePath;

	// first things first -- get the path to the unzipped firmware files
	NSOpenPanel *firmwareOpener = [NSOpenPanel openPanel];
	[firmwareOpener setTitle:@"Select where you unzipped the firmware files"];
	[firmwareOpener setCanChooseDirectories:YES];
	[firmwareOpener setCanChooseFiles:NO];
	[firmwareOpener setAllowsMultipleSelection:NO];
	
	while (1) {
		
		if ([firmwareOpener runModalForTypes:nil] != NSOKButton) {
			return;
		}
		
		firmwarePath = [firmwareOpener filename];
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:[firmwarePath stringByAppendingString:@"/Restore.plist"]]) {
			break;
		}
		
		[mainWindow displayAlert:@"Error" message:@"Specified path does not contain firmware files.  Try again."];
		return;
	}
	
	m_phoneInteraction->enterDFUMode([firmwarePath UTF8String]);
}

- (IBAction)preFirmwareUpgrade:(id)sender
{

	if (m_phoneInteraction->fileExists(PRE_FIRMWARE_UPGRADE_FILE)) {
		[mainWindow displayAlert:@"Already done" message:@"It appears that you have already performed the pre-firmware operation.  If this is not the case, then remove the /private/var/root/Media/disk file from your phone using SSH/SFTP and try again."];
		return;
	}

	bool bCancelled = false;
	NSString *ipAddress, *password;
	
	if ([sshHandler getSSHInfo:&ipAddress password:&password wasCancelled:&bCancelled] == false) {
		return;
	}
	
	if (bCancelled) {
		return;
	}

	NSString *mknodFile = [[NSBundle mainBundle] pathForResource:@"mknod" ofType:@""];
	
	if (mknodFile == nil) {
		[mainWindow displayAlert:@"Error" message:@"Error finding mknod in bundle."];
		return;
	}
	
	m_phoneInteraction->removePath("/mknod");

	if (!m_phoneInteraction->putFile([mknodFile UTF8String], "/mknod")) {
		[mainWindow displayAlert:@"Error" message:@"Error writing /mknod to phone."];
		return;
	}

	bool done = false, taskSuccessful = false;
	int retval;
	
	while (!done) {
		[mainWindow startDisplayWaitingSheet:@"Performing Pre-Firmware Upgrade" message:@"Performing pre-firmware operations..." image:nil
								cancelButton:false runModal:false];
		retval = SSHHelper::mknodDisk([ipAddress UTF8String], [password UTF8String]);
		[mainWindow endDisplayWaitingSheet];

		if (retval != SSH_HELPER_SUCCESS) {

			switch (retval)
			{
				case SSH_HELPER_ERROR_NO_RESPONSE:
					[mainWindow displayAlert:@"Failed" message:@"Couldn't connect to SSH server.  Ensure IP address is correct, phone is connected to a network, and SSH is installed correctly."];
					done = true;
					break;
				case SSH_HELPER_ERROR_BAD_PASSWORD:
					[mainWindow displayAlert:@"Failed" message:@"root password is incorrect."];
					done = true;
					break;
				case SSH_HELPER_VERIFICATION_FAILED:
					NSString *msg = [NSString stringWithFormat:@"Host verification failed.\n\nWould you like iNdependence to try and fix this for you by editing %@/.ssh/known_hosts?", NSHomeDirectory()];
					int retval = NSRunAlertPanel(@"Failed", msg, @"Yes", @"No", nil);

					if (retval == NSAlertDefaultReturn) {

						if (![sshHandler removeKnownHostsEntry:ipAddress]) {
							msg = [NSString stringWithFormat:@"Couldn't remove entry from %@/.ssh/known_hosts.  Please edit that file by hand and remove the line containing your phone's IP address.", NSHomeDirectory()];
							[mainWindow displayAlert:@"Failed" message:msg];
							done = true;
						}
						
					}
					else {
						done = true;
					}

					break;
				default:
					[mainWindow displayAlert:@"Failed" message:@"Error performing pre-firmware operations."];
					done = true;
					break;
			}

		}
		else {
			done = true;
			taskSuccessful = true;
		}

	}

	m_phoneInteraction->removePath("/mknod");

	if (taskSuccessful) {
		[preFirmwareUpgradeButton setEnabled:false];
		[mainWindow displayAlert:@"Success" message:@"Your phone is now ready to be upgraded.\n\nPlease quit iNdependence, then use iTunes to do this now.\n\nEnsure that you choose 'Update' and not 'Restore' in iTunes."];
	}

}

- (IBAction)performSimUnlock:(id)sender
{
	int retval = NSRunAlertPanel(@"Warning", @"If you have previously used iPhoneSimFree to SIM unlock your phone, then you do not need to do this.  You simply need to use Signal.app to reenable your unlock.\n\nDo you wish to continue with SIM unlocking?", @"Yes", @"No", nil);

	if (retval == NSAlertAlternateReturn) {
		return;
	}

	NSString *ramdiskFile = [self getRamdiskPath];
	
	if (ramdiskFile == nil) {
		[mainWindow displayAlert:@"Error" message:@"Error obtaining RAM disk file."];
		return;
	}
	
	m_phoneInteraction->performSIMUnlock([ramdiskFile UTF8String]);
}

- (bool)doPutPEM:(const char*)pemfile
{
	[mainWindow setStatus:@"Putting PEM file on phone..." spinning:true];
	return m_phoneInteraction->putPEMOnPhone(pemfile);
}

- (void)activateStageTwo:(bool)displaySheet
{
	m_waitingForActivation = false;

	if ([self isActivated]) {
		[mainWindow displayAlert:@"Success" message:@"Successfully activated phone."];
		return;
	}

	if (!m_phoneInteraction->factoryActivate()) {
		[mainWindow displayAlert:@"Error" message:@"Error during activation."];
		return;
	}

	if (!m_phoneInteraction->enableYouTube()) {
		[mainWindow displayAlert:@"Error" message:@"Error enabling YouTube."];
		return;
	}

	m_waitingForNewActivation = true;
	g_ignoreJailbreakSuccess = true;
		
	if (displaySheet) {
		[g_mainWindow startDisplayWaitingSheet:nil
									   message:@"Please press and hold the Sleep/Wake button for 3 seconds, then power off your phone, then press Sleep/Wake again to restart it."
										 image:[NSImage imageNamed:@"sleep_button"] cancelButton:false runModal:false];
	}

}

- (void)activationFailed:(const char*)msg
{
	m_waitingForActivation = false;
	[mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
}

- (void)deactivateStageTwo
{
	m_waitingForDeactivation = false;

	if (!m_phoneInteraction->factoryActivate(true)) {
		[mainWindow displayAlert:@"Error" message:@"Error during deactivation."];
		return;
	}

	if (!m_phoneInteraction->enableYouTube(true)) {
		[mainWindow displayAlert:@"Error" message:@"Error disabling YouTube."];
		return;
	}

	m_waitingForNewDeactivation = true;
	[g_mainWindow startDisplayWaitingSheet:nil
								   message:@"Please press and hold the Sleep/Wake button for 3 seconds, then power off your phone, then press Sleep/Wake again to restart it."
									 image:[NSImage imageNamed:@"sleep_button"] cancelButton:false runModal:false];
}

- (void)deactivationFailed:(const char*)msg
{
	m_waitingForDeactivation = false;
	[mainWindow displayAlert:@"Failure" message:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
}

- (IBAction)activate:(id)sender
{
	m_waitingForActivation = true;
	
	if (!m_phoneInteraction->isPhoneJailbroken()) {
		char *value = m_phoneInteraction->getPhoneProductVersion();
		
		if (!strncmp(value, "1.0", 3) || !strncmp(value, "1.1.1", 5) || !strncmp(value, "1.1.2", 5)) {
			[self performJailbreak:sender];
		}
		else {
			NSString *ramdiskFile = [self getRamdiskPath];

			if (ramdiskFile == nil) {
				[mainWindow displayAlert:@"Error" message:@"Error obtaining RAM disk file."];
				return;
			}

			m_phoneInteraction->performJailbreak(true, [ramdiskFile UTF8String]);
		}

		return;
	}
	
	[self activateStageTwo:true];
}

- (IBAction)deactivate:(id)sender
{
	m_waitingForDeactivation = true;
	
	if (!m_phoneInteraction->isPhoneJailbroken()) {
		[self performJailbreak:sender];
		return;
	}
	
	[self deactivateStageTwo];
}

- (IBAction)waitDialogCancel:(id)sender
{

	if (m_installingSSH) {
		m_installingSSH = false;
		[mainWindow endDisplayWaitingSheet];
		[self finishInstallingSSH:true];
	}
	
}

- (IBAction)changePassword:(id)sender
{
	[NSApp beginSheet:newPasswordDialog modalForWindow:mainWindow modalDelegate:nil didEndSelector:nil
		  contextInfo:nil];

	const char *accountName = NULL;
	const char *newPassword = NULL;

	while ( !accountName || !newPassword ) {

		if ([NSApp runModalForWindow:newPasswordDialog] == -1) {
			[NSApp endSheet:newPasswordDialog];
			[newPasswordDialog orderOut:self];
			return;
		}

		[NSApp endSheet:newPasswordDialog];
		[newPasswordDialog orderOut:self];

		if ([[accountNameField stringValue] length] == 0) {
			[mainWindow displayAlert:@"Error" message:@"Invalid account name.  Try again."];
			continue;
		}

		if ([[passwordField stringValue] length] == 0) {
			[mainWindow displayAlert:@"Error" message:@"Invalid password.  Try again."];
			continue;
		}

		if (![[passwordField stringValue] isEqualToString:[passwordAgainField stringValue]]) {
			[mainWindow displayAlert:@"Error" message:@"Passwords don't match.  Try again."];
			continue;
		}

		accountName = [[accountNameField stringValue] UTF8String];
		newPassword = [[passwordField stringValue] UTF8String];
	}

	int size = 0;
	char *buf, *offset;

	if (!m_phoneInteraction->getFileData((void**)&buf, &size, "/etc/master.passwd")) {
		[mainWindow displayAlert:@"Error" message:@"Error reading /etc/master.passwd from phone."];
		return;
	}

	int accountLen = strlen(accountName);
	char pattern[accountLen+2];

	strcpy(pattern, accountName);
	pattern[accountLen] = ':';
	pattern[accountLen+1] = 0;

	if ( (offset = strstr(buf, pattern)) == NULL ) {
		free(buf);
		[mainWindow displayAlert:@"Error" message:@"No such account name in master.passwd."];
		return;
	}

	char *encryptedPassword = crypt(newPassword, "XU");
	
	if (encryptedPassword == NULL) {
		free(buf);
		[mainWindow displayAlert:@"Error" message:@"Error encrypting given password."];
		return;
	}

	strncpy(offset + accountLen + 1, encryptedPassword, 13);

	if (!m_phoneInteraction->putData(buf, size, "/etc/master.passwd")) {
		free(buf);
		[mainWindow displayAlert:@"Error" message:@"Error writing to /etc/master.passwd on phone."];
		return;
	}

	free(buf);
	[mainWindow displayAlert:@"Success" message:@"Successfully changed account password."];
}

- (IBAction)passwordDialogCancel:(id)sender
{
	[NSApp stopModalWithCode:-1];
}

- (IBAction)passwordDialogOk:(id)sender
{
	[NSApp stopModalWithCode:0];
}

- (IBAction)installSSH:(id)sender
{
	[mainWindow startDisplayWaitingSheet:nil
								 message:@"Generating SSH keys..."
								   image:nil cancelButton:false runModal:false];

	// first generate the RSA and DSA keys
	NSString *sshKeygenPath = @"/usr/bin/ssh-keygen";
	NSString *tmpDir = NSTemporaryDirectory();
	NSMutableString *sshHostKey = [NSMutableString stringWithString:tmpDir];
	[sshHostKey appendString:@"/ssh_host_key"];
	NSMutableString *sshHostKeyPub = [NSMutableString stringWithString:sshHostKey];
	[sshHostKeyPub appendString:@".pub"];

	// remove old files if they exist
	remove([sshHostKey UTF8String]);
	remove([sshHostKeyPub UTF8String]);

	NSArray *args = [NSArray arrayWithObjects:@"-t", @"rsa1", @"-f", sshHostKey, @"-N", @"", nil];
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:sshKeygenPath];
	[task setArguments:args];
	[task launch];
	[task waitUntilExit];

	if ([task terminationStatus] != 0) {
		[task release];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error occurred while executing ssh-keygen."];
		return;
	}

	[task release];

	NSMutableString *sshHostRSAKey = [NSMutableString stringWithString:tmpDir];
	[sshHostRSAKey appendString:@"/ssh_host_rsa_key"];
	NSMutableString *sshHostRSAKeyPub = [NSMutableString stringWithString:sshHostRSAKey];
	[sshHostRSAKeyPub appendString:@".pub"];

	// remove old files if they exist
	remove([sshHostRSAKey UTF8String]);
	remove([sshHostRSAKeyPub UTF8String]);

	args = [NSArray arrayWithObjects:@"-t", @"rsa", @"-f", sshHostRSAKey, @"-N", @"", nil];
	task = [[NSTask alloc] init];
	[task setLaunchPath:sshKeygenPath];
	[task setArguments:args];
	[task launch];
	[task waitUntilExit];

	if ([task terminationStatus] != 0) {
		[task release];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error occurred while executing ssh-keygen."];
		return;
	}

	[task release];

	NSMutableString *sshHostDSAKey = [NSMutableString stringWithString:tmpDir];
	[sshHostDSAKey appendString:@"/ssh_host_dsa_key"];
	NSMutableString *sshHostDSAKeyPub = [NSMutableString stringWithString:sshHostDSAKey];
	[sshHostDSAKeyPub appendString:@".pub"];
	
	// remove old files if they exist
	remove([sshHostDSAKey UTF8String]);
	remove([sshHostDSAKeyPub UTF8String]);

	args = [NSArray arrayWithObjects:@"-t", @"dsa", @"-f", sshHostDSAKey, @"-N", @"", nil];
	task = [[NSTask alloc] init];
	[task setLaunchPath:sshKeygenPath];
	[task setArguments:args];
	[task launch];
	[task waitUntilExit];
	
	if ([task terminationStatus] != 0) {
		[task release];
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error occurred while executing ssh-keygen."];
		return;
	}
	
	[task release];

	if (!m_phoneInteraction->createDirectory("/etc/ssh")) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error creating /etc/ssh directory on phone."];
		return;
	}

	if (!m_phoneInteraction->putFile([sshHostKey UTF8String], "/etc/ssh/ssh_host_key")) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /etc/ssh/ssh_host_key to phone."];
		return;
	}

	if (!m_phoneInteraction->putFile([sshHostKeyPub UTF8String], "/etc/ssh/ssh_host_key.pub")) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /etc/ssh/ssh_host_key.pub to phone."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([sshHostRSAKey UTF8String], "/etc/ssh/ssh_host_rsa_key")) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /etc/ssh/ssh_host_rsa_key to phone."];
		return;
	}

	if (!m_phoneInteraction->putFile([sshHostRSAKeyPub UTF8String], "/etc/ssh/ssh_host_rsa_key.pub")) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /etc/ssh/ssh_host_rsa_key.pub to phone."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([sshHostDSAKey UTF8String], "/etc/ssh/ssh_host_dsa_key")) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /etc/ssh/ssh_host_dsa_key to phone."];
		return;
	}

	if (!m_phoneInteraction->putFile([sshHostDSAKeyPub UTF8String], "/etc/ssh/ssh_host_dsa_key.pub")) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /etc/ssh/ssh_host_dsa_key.pub to phone."];
		return;
	}
	
	NSString *sshdConfigFile = [[NSBundle mainBundle] pathForResource:@"sshd_config" ofType:@""];

	if (sshdConfigFile == nil) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error finding sshd_config in bundle."];
		return;
	}

	if (!m_phoneInteraction->putFile([sshdConfigFile UTF8String], "/etc/ssh/sshd_config")) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /etc/ssh/sshd_config to phone."];
		return;
	}

	NSString *chmodFile = [[NSBundle mainBundle] pathForResource:@"chmod" ofType:@""];

	if (chmodFile == nil) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error finding chmod in bundle."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([chmodFile UTF8String], "/bin/chmod")) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /bin/chmod to phone."];
		return;
	}

	NSString *shFile = [[NSBundle mainBundle] pathForResource:@"sh" ofType:@""];

	if (shFile == nil) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error finding sh in bundle."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([shFile UTF8String], "/bin/sh")) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /bin/sh to phone."];
		return;
	}

	NSString *sftpFile = [[NSBundle mainBundle] pathForResource:@"sftp-server" ofType:@""];

	if (sftpFile == nil) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error finding sftp-server in bundle."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([sftpFile UTF8String], "/usr/libexec/sftp-server")) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /usr/libexec/sftp-server to phone."];
		return;
	}

	NSString *scpFile = [[NSBundle mainBundle] pathForResource:@"scp" ofType:@""];
	
	if (scpFile == nil) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error finding scp in bundle."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([scpFile UTF8String], "/usr/bin/scp")) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /usr/bin/scp to phone."];
		return;
	}

	NSString *libarmfpFile = [[NSBundle mainBundle] pathForResource:@"libarmfp" ofType:@"dylib"];
	
	if (libarmfpFile == nil) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error finding libarmfp.dylib in bundle."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([libarmfpFile UTF8String], "/usr/lib/libarmfp.dylib")) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /usr/lib/libarmfp.dylib to phone."];
		return;
	}
	
	NSString *sshdFile = [[NSBundle mainBundle] pathForResource:@"sshd" ofType:@""];

	if (sshdFile == nil) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error finding sshd in bundle."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([sshdFile UTF8String], "/usr/sbin/sshd")) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /usr/sbin/sshd to phone."];
		return;
	}
	
	NSMutableString *tmpFilePath = [NSMutableString stringWithString:tmpDir];
	[tmpFilePath appendString:@"/update.backup.iNdependence"];

	// remove old file if it exists
	remove([tmpFilePath UTF8String]);

	if (!m_phoneInteraction->getFile("/usr/sbin/update", [tmpFilePath UTF8String])) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error reading /usr/sbin/update from phone."];
		return;
	}

	if (!m_phoneInteraction->putFile([chmodFile UTF8String], "/usr/sbin/update")) {
		remove([tmpFilePath UTF8String]);
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /usr/sbin/update to phone."];
		return;
	}

	NSMutableString *tmpFilePath2 = [NSMutableString stringWithString:tmpDir];
	[tmpFilePath2 appendString:@"/com.apple.update.plist.backup.iNdependence"];

	// remove old file if it exists
	remove([tmpFilePath2 UTF8String]);

	if (!m_phoneInteraction->getFile("/System/Library/LaunchDaemons/com.apple.update.plist", [tmpFilePath2 UTF8String])) {
		m_phoneInteraction->putFile([tmpFilePath UTF8String], "/usr/sbin/update");
		remove([tmpFilePath UTF8String]);
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error reading /System/Library/LaunchDaemons/com.apple.update.plist from phone."];
		return;
	}

	int fd = open([tmpFilePath2 UTF8String], O_RDONLY, 0);

	if (fd == -1) {
		m_phoneInteraction->putFile([tmpFilePath UTF8String], "/usr/sbin/update");
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error opening com.apple.update.plist.backup.iNdependence for reading."];
		return;
	}

	struct stat st;

	if (fstat(fd, &st) == -1) {
		close(fd);
		m_phoneInteraction->putFile([tmpFilePath UTF8String], "/usr/sbin/update");
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error obtaining com.apple.update.plist.original file size."];
		return;
	}

	NSMutableString *tmpFilePath3 = [NSMutableString stringWithString:tmpDir];
	[tmpFilePath3 appendString:@"/com.apple.update.plist.iNdependence"];
	int fd2 = open([tmpFilePath3 UTF8String], O_CREAT | O_TRUNC | O_WRONLY,
				   S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);

	if (fd2 == -1) {
		close(fd);
		m_phoneInteraction->putFile([tmpFilePath UTF8String], "/usr/sbin/update");
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error opening com.apple.update.plist.iNdependence for writing."];
		return;
	}

	unsigned char buf[1024];
	int readCount = 0;

	while (readCount < st.st_size) {
		int retval = read(fd, buf, 1024);

		if (retval < 1) {
			break;
		}

		write(fd2, buf, retval);
		readCount += retval;
	}

	close(fd);
	close(fd2);

	if (readCount < st.st_size) {
		m_phoneInteraction->putFile([tmpFilePath UTF8String], "/usr/sbin/update");
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		remove([tmpFilePath3 UTF8String]);
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error copying com.apple.update.plist."];
		return;
	}

	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:tmpFilePath3];
	NSMutableDictionary *mutDict = [NSMutableDictionary dictionaryWithCapacity:[dict count]];
	[mutDict addEntriesFromDictionary:dict];
	NSMutableArray *mutArgs = [NSMutableArray arrayWithCapacity:5];
	[mutArgs addObject:@"/usr/sbin/update"];
	[mutArgs addObject:@"555"];
	[mutArgs addObject:@"/bin/chmod"];
	[mutArgs addObject:@"/bin/sh"];
	[mutArgs addObject:@"/usr/sbin/sshd"];
	[mutArgs addObject:@"/usr/libexec/sftp-server"];
	[mutArgs addObject:@"/usr/bin/scp"];
	[mutDict setObject:mutArgs forKey:@"ProgramArguments"];

	if (remove([tmpFilePath3 UTF8String]) == -1) {
		m_phoneInteraction->putFile([tmpFilePath UTF8String], "/usr/sbin/update");
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error deleting com.apple.update.plist.iNdependence"];
		return;
	}

	if (![mutDict writeToFile:tmpFilePath3 atomically:YES]) {
		m_phoneInteraction->putFile([tmpFilePath UTF8String], "/usr/sbin/update");
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		remove([tmpFilePath3 UTF8String]);
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error creating new com.apple.update.plist."];
		return;
	}

	if (!m_phoneInteraction->putFile([tmpFilePath3 UTF8String], "/System/Library/LaunchDaemons/com.apple.update.plist")) {
		m_phoneInteraction->putFile([tmpFilePath UTF8String], "/usr/sbin/update");
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		remove([tmpFilePath3 UTF8String]);
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /System/Library/LaunchDaemons/com.apple.update.plist to phone."];
		return;
	}

	NSString *sshPlistFile = [[NSBundle mainBundle] pathForResource:@"com.openssh.sshd" ofType:@"plist"];

	if (sshPlistFile == nil) {
		m_phoneInteraction->putFile([tmpFilePath UTF8String], "/usr/sbin/update");
		m_phoneInteraction->putFile([tmpFilePath2 UTF8String], "/System/Library/LaunchDaemons/com.apple.update.plist");
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		remove([tmpFilePath3 UTF8String]);
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error finding com.openssh.sshd.plist in bundle."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([sshPlistFile UTF8String], "/Library/LaunchDaemons/com.openssh.sshd.plist")) {
		m_phoneInteraction->putFile([tmpFilePath UTF8String], "/usr/sbin/update");
		m_phoneInteraction->putFile([tmpFilePath2 UTF8String], "/System/Library/LaunchDaemons/com.apple.update.plist");
		remove([tmpFilePath UTF8String]);
		remove([tmpFilePath2 UTF8String]);
		remove([tmpFilePath3 UTF8String]);
		[mainWindow endDisplayWaitingSheet];
		[mainWindow displayAlert:@"Error" message:@"Error writing /Library/LaunchDaemons/com.openssh.sshd.plist to phone."];
		return;
	}

	m_installingSSH = true;
	m_bootCount = 0;

	[mainWindow endDisplayWaitingSheet];
#ifdef DEBUG
	[mainWindow startDisplayWaitingSheet:nil
								 message:@"Rebooting the phone..."
								   image:nil cancelButton:false runModal:false];

	if (!m_phoneInteraction->reboot()) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow startDisplayWaitingSheet:nil
									 message:@"Couldn't reboot phone automatically.\n\nPlease reboot your phone manually by pressing and holding the Sleep/Wake button for 3 seconds, then powering off your phone, then pressing Sleep/Wake again for a second to restart it..."
									   image:[NSImage imageNamed:@"sleep_button"] cancelButton:false runModal:false];
	}
#else
	[mainWindow startDisplayWaitingSheet:nil
								 message:@"Please reboot your phone by pressing and holding the Sleep/Wake button for 3 seconds, then powering off your phone, then pressing Sleep/Wake again for a second to restart it..."
								   image:[NSImage imageNamed:@"sleep_button"] cancelButton:false runModal:false];
#endif

}

- (void)sshInstallStageTwo
{
	NSMutableString *backupFilePath = [NSMutableString stringWithString:NSTemporaryDirectory()];
	[backupFilePath appendString:@"/com.apple.update.plist.iNdependence"];

	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:backupFilePath];
	NSMutableDictionary *mutDict = [NSMutableDictionary dictionaryWithCapacity:[dict count]];
	[mutDict addEntriesFromDictionary:dict];
	NSMutableArray *mutArgs = [NSMutableArray arrayWithCapacity:5];
	[mutArgs addObject:@"/usr/sbin/update"];
	[mutArgs addObject:@"600"];
	[mutArgs addObject:@"/etc/ssh/ssh_host_key"];
	[mutArgs addObject:@"/etc/ssh/ssh_host_rsa_key"];
	[mutArgs addObject:@"/etc/ssh/ssh_host_dsa_key"];
	[mutDict setObject:mutArgs forKey:@"ProgramArguments"];

	remove([backupFilePath UTF8String]);
	
	if (![mutDict writeToFile:backupFilePath atomically:YES]) {
		[self finishInstallingSSH:true];
		[mainWindow displayAlert:@"Error" message:@"Error creating new com.apple.update.plist."];
		return;
	}

	if (!m_phoneInteraction->putFile([backupFilePath UTF8String], "/System/Library/LaunchDaemons/com.apple.update.plist")) {
		[self finishInstallingSSH:true];
		[mainWindow displayAlert:@"Error" message:@"Error writing /System/Library/LaunchDaemons/com.apple.update.plist to phone."];
		return;
	}

#ifdef DEBUG
	[mainWindow startDisplayWaitingSheet:nil
								 message:@"Rebooting the phone a second time..."
								   image:nil cancelButton:false runModal:false];

	if (!m_phoneInteraction->reboot()) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow startDisplayWaitingSheet:nil
									 message:@"Couldn't reboot phone automatically.\n\nPlease reboot your phone manually by pressing and holding the Sleep/Wake button for 3 seconds, then powering off your phone, then pressing Sleep/Wake again to restart it..."
									   image:[NSImage imageNamed:@"sleep_button"] cancelButton:false runModal:false];
	}
#else
	[mainWindow startDisplayWaitingSheet:nil
								 message:@"Please reboot your phone again using the same steps..."
								   image:[NSImage imageNamed:@"sleep_button"] cancelButton:false runModal:false];
#endif

}

- (void)sshInstallStageThree
{
	NSString *tmpDir = NSTemporaryDirectory();
	NSMutableString *backupFilePath = [NSMutableString stringWithString:tmpDir];
	[backupFilePath appendString:@"/com.apple.update.plist.backup.iNdependence"];
	NSMutableString *backupFilePath2 = [NSMutableString stringWithString:tmpDir];
	[backupFilePath2 appendString:@"/update.backup.iNdependence"];
	NSMutableString *backupFilePath3 = [NSMutableString stringWithString:tmpDir];
	[backupFilePath3 appendString:@"/com.apple.update.plist.iNdependence"];
	
	if (!m_phoneInteraction->putFile([backupFilePath UTF8String], "/System/Library/LaunchDaemons/com.apple.update.plist")) {
		[self finishInstallingSSH:true];
		return;
	}
	
	if (!m_phoneInteraction->putFile([backupFilePath2 UTF8String], "/usr/sbin/update")) {
		[self finishInstallingSSH:true];
		return;
	}

#ifdef DEBUG
	[mainWindow startDisplayWaitingSheet:nil
								 message:@"Rebooting the phone a final time..."
								   image:nil cancelButton:false runModal:false];

	if (!m_phoneInteraction->reboot()) {
		[mainWindow endDisplayWaitingSheet];
		[mainWindow startDisplayWaitingSheet:nil
									 message:@"Couldn't reboot phone automatically.\n\nPlease reboot your phone manually by pressing and holding the Sleep/Wake button for 3 seconds, then powering off your phone, then pressing Sleep/Wake again to restart it..."
									   image:[NSImage imageNamed:@"sleep_button"] cancelButton:false runModal:false];
	}
#else
	[mainWindow startDisplayWaitingSheet:nil
								 message:@"Please reboot your phone one final time using the same steps..."
								   image:[NSImage imageNamed:@"sleep_button"] cancelButton:false runModal:false];
#endif

}

- (void)finishInstallingSSH:(bool)bCancelled
{
	m_installingSSH = false;
	m_bootCount = 0;

	NSString *tmpDir = NSTemporaryDirectory();
	NSMutableString *backupFilePath = [NSMutableString stringWithString:tmpDir];
	[backupFilePath appendString:@"/com.apple.update.plist.backup.iNdependence"];
	NSMutableString *backupFilePath2 = [NSMutableString stringWithString:tmpDir];
	[backupFilePath2 appendString:@"/update.backup.iNdependence"];
	NSMutableString *backupFilePath3 = [NSMutableString stringWithString:tmpDir];
	[backupFilePath3 appendString:@"/com.apple.update.plist.iNdependence"];
	
	if (!m_phoneInteraction->putFile([backupFilePath UTF8String], "/System/Library/LaunchDaemons/com.apple.update.plist")) {
		m_phoneInteraction->putFile([backupFilePath2 UTF8String], "/usr/sbin/update");
		remove([backupFilePath UTF8String]);
		remove([backupFilePath2 UTF8String]);
		remove([backupFilePath3 UTF8String]);
		[mainWindow displayAlert:@"Error" message:@"Error restoring original /System/Library/LaunchDaemons/com.apple.update.plist on phone.  Please try installing SSH again."];
		return;
	}
	
	if (!m_phoneInteraction->putFile([backupFilePath2 UTF8String], "/usr/sbin/update")) {
		remove([backupFilePath UTF8String]);
		remove([backupFilePath2 UTF8String]);
		remove([backupFilePath3 UTF8String]);
		[mainWindow displayAlert:@"Error" message:@"Error restoring original /usr/sbin/update on phone.  Please try installing SSH again."];
		return;
	}
	
	// clean up
	remove([backupFilePath UTF8String]);
	remove([backupFilePath2 UTF8String]);
	remove([backupFilePath3 UTF8String]);

	if (!bCancelled) {
		[mainWindow displayAlert:@"Success" message:@"Successfully installed SSH, SFTP, and SCP on your phone."];
	}
	
}

- (IBAction)removeSSH:(id)sender
{
	[libarmfpRemovalButton setState:NSOffState];
	[shRemovalButton setState:NSOffState];
	[chmodRemovalButton setState:NSOffState];

	[NSApp beginSheet:sshRemovalDialog modalForWindow:mainWindow modalDelegate:nil
	   didEndSelector:nil contextInfo:nil];

	if ([NSApp runModalForWindow:sshRemovalDialog] == -1) {
		[NSApp endSheet:sshRemovalDialog];
		[sshRemovalDialog orderOut:self];
		return;
	}

	[NSApp endSheet:sshRemovalDialog];
	[sshRemovalDialog orderOut:self];

	bool bRemoveLibarmfp = false, bRemoveSh = false, bRemoveChmod = false;

	if ([libarmfpRemovalButton state] == NSOnState) {
		bRemoveLibarmfp = true;
	}

	if ([shRemovalButton state] == NSOnState) {
		bRemoveSh = true;
	}

	if ([chmodRemovalButton state] == NSOnState) {
		bRemoveChmod = true;
	}

	if ([self isDropbearSSHInstalled]) {

		if (!m_phoneInteraction->removePath("/usr/bin/dropbear")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing /usr/bin/dropbear from phone."];
			return;
		}

		if (!m_phoneInteraction->removePath("/usr/libexec/sftp-server")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing /usr/libexec/sftp-server from phone."];
			return;
		}
	
		if (!m_phoneInteraction->removePath("/etc/dropbear/dropbear_rsa_host_key")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing /etc/dropbear/dropbear_rsa_host_key from phone."];
			return;
		}

		if (!m_phoneInteraction->removePath("/etc/dropbear/dropbear_dss_host_key")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing /etc/dropbear/dropbear_dss_host_key from phone."];
			return;
		}

		if (!m_phoneInteraction->removePath("/etc/dropbear")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing /etc/dropbear from phone."];
			return;
		}

		if (!m_phoneInteraction->removePath("/System/Library/LaunchDaemons/au.asn.ucc.matt.dropbear.plist")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing /System/Library/LaunchDaemons/au.asn.ucc.matt.dropbear.plist from phone."];
			return;
		}
		
	}

	if ([self isOpenSSHInstalled]) {
		
		if (!m_phoneInteraction->removePath("/usr/sbin/sshd")) {

			if (!m_phoneInteraction->removePath("/usr/bin/sshd")) {
				[mainWindow displayAlert:@"Error" message:@"Error removing sshd from phone."];
				return;
			}

		}

		// Extra just in case both files are installed
		m_phoneInteraction->removePath("/usr/bin/sshd");

		if (!m_phoneInteraction->removePath("/usr/libexec/sftp-server")) {

			if (!m_phoneInteraction->removePath("/usr/bin/sftp-server")) {
				[mainWindow displayAlert:@"Error" message:@"Error removing sftp-server from phone."];
				return;
			}

		}

		// Extra just in case both files are installed
		m_phoneInteraction->removePath("/usr/bin/sftp-server");

		if (!m_phoneInteraction->removePath("/etc/ssh/ssh_host_key")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing ssh_host_key from phone."];
			return;
		}
		
		if (!m_phoneInteraction->removePath("/etc/ssh/ssh_host_key.pub")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing ssh_host_key.pub from phone."];
			return;
		}
		
		if (!m_phoneInteraction->removePath("/etc/ssh/ssh_host_rsa_key")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing ssh_host_rsa_key from phone."];
			return;
		}
		
		if (!m_phoneInteraction->removePath("/etc/ssh/ssh_host_rsa_key.pub")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing ssh_host_rsa_key.pub from phone."];
			return;
		}
		
		if (!m_phoneInteraction->removePath("/etc/ssh/ssh_host_dsa_key")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing ssh_host_dsa_key from phone."];
			return;
		}
		
		if (!m_phoneInteraction->removePath("/etc/ssh/ssh_host_dsa_key.pub")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing ssh_host_dsa_key.pub from phone."];
			return;
		}
		
		if (!m_phoneInteraction->removePath("/etc/ssh")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing /etc/ssh from phone."];
			return;
		}
		
		if (!m_phoneInteraction->removePath("/Library/LaunchDaemons/com.openssh.sshd.plist")) {

			if (!m_phoneInteraction->removePath("/System/Library/LaunchDaemons/org.thebends.openssh.plist")) {
				[mainWindow displayAlert:@"Error" message:@"Error removing LaunchDaemon plist file from phone."];
				return;
			}

		}

		// Extra just in case both files are installed
		m_phoneInteraction->removePath("/System/Library/LaunchDaemons/org.thebends.openssh.plist");
	}

	[installSSHButton setEnabled:YES];
	[removeSSHButton setEnabled:NO];

	if (!m_phoneInteraction->removePath("/usr/bin/scp")) {
		[mainWindow displayAlert:@"Error" message:@"Error removing scp from phone."];
		return;
	}

	if (bRemoveLibarmfp) {

		if (!m_phoneInteraction->removePath("/usr/lib/libarmfp.dylib")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing libarmfp.dylib from phone."];
			return;
		}

	}

	if (bRemoveChmod) {

		if (!m_phoneInteraction->removePath("/bin/chmod")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing chmod from phone."];
			return;
		}

	}

	if (bRemoveSh) {

		if (!m_phoneInteraction->removePath("/bin/sh")) {
			[mainWindow displayAlert:@"Error" message:@"Error removing sh from phone."];
			return;
		}

	}

	[mainWindow displayAlert:@"Success" message:@"Successfully removed SSH, SFTP, and SCP from your phone.\n\nNote that SSH will continue to run on the phone until you reboot it."];
}

- (IBAction)sshRemovalDialogCancel:(id)sender
{
	[NSApp stopModalWithCode:-1];
}

- (IBAction)sshRemovalDialogOk:(id)sender
{
	[NSApp stopModalWithCode:0];
}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
	
	switch ([menuItem tag]) {
		case MENU_ITEM_ACTIVATE:

			if (![self isConnected] || [self isActivated]) {
				return NO;
			}

			break;
		case MENU_ITEM_DEACTIVATE:
			
			if (![self isConnected] || ![self isActivated]) {
				return NO;
			}

			break;
		case MENU_ITEM_ENTER_RECOVERY_MODE:

			if ([self isInRecoveryMode]) {
				[menuItem setTitle:@"Exit Recovery Mode"];
			}
			else if (![self isConnected]) {
				return NO;
			}

			break;
		case MENU_ITEM_ENTER_DFU_MODE:
			
			if (![self isConnected]) {
				return NO;
			}
			
			break;
		case MENU_ITEM_JAILBREAK:
			
			if (![self isConnected] || [self isJailbroken]) {
				return NO;
			}
			
			break;
		case MENU_ITEM_INSTALL_SSH:

			if (![self isConnected] || ![self isJailbroken] || [self isSSHInstalled]) {
				return NO;
			}

			break;
		case MENU_ITEM_REMOVE_SSH:

			if (![self isConnected] || ![self isJailbroken] || ![self isSSHInstalled]) {
				return NO;
			}
			
			break;
		case MENU_ITEM_RETURN_TO_JAIL:
			
			if (![self isConnected] || ![self isJailbroken]) {
				return NO;
			}
			
			break;
		case MENU_ITEM_CHANGE_PASSWORD:
			
			if (![self isConnected] || ![self isJailbroken]) {
				return NO;
			}

			break;
		case MENU_ITEM_PRE_FIRMWARE_UPGRADE:

			if (![self isConnected] || ![self isJailbroken] || ![self isSSHInstalled] ||
				m_phoneInteraction->fileExists(PRE_FIRMWARE_UPGRADE_FILE)) {
				return NO;
			}

			break;
		case MENU_ITEM_PERFORM_SIM_UNLOCK:
			
			if (![self isConnected]) {
				return NO;
			}

			break;
		default:
			break;
	}
	
	return YES;
}

- (void)updateInfo
{

	if (![self isConnected]) {
		[iTunesVersionField setStringValue:@"-"];
		[productVersionField setStringValue:@"-"];
		[basebandVersionField setStringValue:@"-"];
		[firmwareVersionField setStringValue:@"-"];
		[buildVersionField setStringValue:@"-"];
		[serialNumberField setStringValue:@"-"];
		[activationStateField setStringValue:@"-"];
		[jailbrokenField setStringValue:@"-"];
		[sshInstalledField setStringValue:@"-"];
		return;
	}

	PIVersion iTunesVersion = m_phoneInteraction->getiTunesVersion();

	[iTunesVersionField setStringValue:[NSString stringWithFormat:@"%d.%d.%d", iTunesVersion.major, iTunesVersion.minor, iTunesVersion.point]];

	if (m_phoneInteraction->getPhoneProductVersion() != NULL) {
		[productVersionField setStringValue:[NSString stringWithCString:m_phoneInteraction->getPhoneProductVersion() encoding:NSUTF8StringEncoding]];
	}
	else {
		[productVersionField setStringValue:@"-"];
	}

	if (m_phoneInteraction->getPhoneBasebandVersion() != NULL) {
		[basebandVersionField setStringValue:[NSString stringWithCString:m_phoneInteraction->getPhoneBasebandVersion() encoding:NSUTF8StringEncoding]];
	}
	else {
		[basebandVersionField setStringValue:@"-"];
	}

	if (m_phoneInteraction->getPhoneFirmwareVersion() != NULL) {
		[firmwareVersionField setStringValue:[NSString stringWithCString:m_phoneInteraction->getPhoneFirmwareVersion() encoding:NSUTF8StringEncoding]];
	}
	else {
		[firmwareVersionField setStringValue:@"-"];
	}

	if (m_phoneInteraction->getPhoneBuildVersion() != NULL) {
		[buildVersionField setStringValue:[NSString stringWithCString:m_phoneInteraction->getPhoneBuildVersion() encoding:NSUTF8StringEncoding]];
	}
	else {
		[buildVersionField setStringValue:@"-"];
	}

	if (m_phoneInteraction->getPhoneSerialNumber() != NULL) {
		[serialNumberField setStringValue:[NSString stringWithCString:m_phoneInteraction->getPhoneSerialNumber() encoding:NSUTF8StringEncoding]];
	}
	else {
		[serialNumberField setStringValue:@"-"];
	}

	if (m_phoneInteraction->getPhoneActivationState() != NULL) {
		[activationStateField setStringValue:[NSString stringWithCString:m_phoneInteraction->getPhoneActivationState() encoding:NSUTF8StringEncoding]];
	}
	else {
		[activationStateField setStringValue:@"-"];
	}

	if ([self isJailbroken]) {
		[jailbrokenField setStringValue:@"Yes"];
	}
	else {
		[jailbrokenField setStringValue:@"No"];
	}

	if ([self isSSHInstalled]) {
		[sshInstalledField setStringValue:@"Yes"];
	}
	else {
		[sshInstalledField setStringValue:@"No"];
	}

}

@end
