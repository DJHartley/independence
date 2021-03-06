/*
 *  AppController.h
 *  iNdependence MobDev Tool
 *
 *  Created by The Operator on 08/11/07.
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

#import <Cocoa/Cocoa.h>


@interface AppController : NSObject
{
	NSString *iTunesVersion;
}

- (BOOL)determineiTunesVersion;
- (BOOL)validateMobileDeviceVersion:(NSString*)mobDevPath;
- (void)doStuff;

@end
