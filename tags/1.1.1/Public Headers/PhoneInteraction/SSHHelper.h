/*
 *  SSHHelper.h
 *  libPhoneInteraction
 *
 *  Created by The Operator on 31/08/07.
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

#pragma once


enum {
	SSH_HELPER_SUCCESS = 0,
	SSH_HELPER_ERROR_NO_RESPONSE = 256,
	SSH_HELPER_ERROR_BAD_PASSWORD = 512,
};

class SSHHelper
{
public:

	// Used to recursively copy file permissions from srcPath to destPath via SSH
	static int copyPermissions(const char *srcPath, const char *destPath,
							   const char *ipAddress, const char *password,
							   bool bRestartSpringboard = true);

	// Used to restart Springboard after adding/removing an application
	static int restartSpringboard(const char *ipAddress, const char *password);

};