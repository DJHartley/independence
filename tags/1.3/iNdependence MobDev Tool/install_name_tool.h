/*
 *  install_name_tool.h
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

/* Used to change the install name for a dylib */
int changeInstallName(const char *newname, const char *dylib);
