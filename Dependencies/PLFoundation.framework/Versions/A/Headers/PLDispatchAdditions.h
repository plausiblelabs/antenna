/*
 * Copyright (c) 2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <dispatch/dispatch.h>

/**
 * Returns the default priority global queue.
 */
#define PL_DEFAULT_QUEUE (dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))

/**
 * Returns a dispatch time value for @a _s seconds from the current time.
 *
 * @param _s Relative time in seconds.
 */
#define pl_dispatch_time_secs(_s) (dispatch_time(DISPATCH_TIME_NOW, (_s ## LL * NSEC_PER_SEC)))