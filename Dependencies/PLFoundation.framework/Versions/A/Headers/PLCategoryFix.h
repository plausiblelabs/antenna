/*
 * Copyright (c) 2010-2013 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <AvailabilityMacros.h>

#if TARGET_OS_IPHONE || defined(__LP64__)

/**
 * Provides a work-around for the iOS/64-bit category linker bug described in Apple Technical Q&A QA1490.
 *
 * From the Apple Technical Q&A QA1490:
 *
 *    IMPORTANT: For 64-bit and iPhone OS applications, there is a linker bug 
 *    that prevents -ObjC from loading objects files from static libraries that
 *    contain only categories and no classes. The workaround is to use the -all_load
 *    or -force_load flags.
 *
 * Unfortunately, this proposed fix triggers an additional libtool bug; The use of -all_load
 * causes libtool to ignore the -arch_only flag when linking together static libraries,
 * resulting in duplicate object files for different architectures being linked into
 * the same static archive.
 *
 * On architectures affected by this bug, this macro will declare a stub class that causes the linker
 * to properly include the categories' implementation in its output. This works around
 * the linker issue described in QA1490, and avoids requiring the use of -all_load.
 *
 * This macro is a no-op on architectures that are not affected by the QA1490 issue.
 *
 * @par Usage Example
 * To use, simply add to your category's implementation file:
 *
 * @code
 * PL_CATEGORY_FIX(ExampleCategoryName);
 * @endcode
 *
 * @sa http://developer.apple.com/library/mac/#qa/qa2006/qa1490.html
 *
 * @note While this work-around avoids requiring the use of the -all_load linker flag, the -ObjC flag is still required
 * when linking to avoid dead-stripping of classes or categories. Refer to the ld man page for more details.
 */
#define PL_CATEGORY_FIX(name) \
    @interface PLCategoryLinkerFix_ ## name : NSObject @end \
    @implementation PLCategoryLinkerFix_ ## name @end

#else

#define PL_CATEGORY_FIX(name)

#endif