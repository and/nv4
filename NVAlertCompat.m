//
//  NVAlertCompat.m
//  Notation
//
//  Compatibility shims for NSRunAlertPanel and related APIs
//  that were removed from the macOS SDK in Xcode 14+.
//

#import <Cocoa/Cocoa.h>

// Helper to map NSAlert modal response to legacy alert return values
static NSInteger NVAlertReturnFromResponse(NSModalResponse response) {
	if (response == NSAlertFirstButtonReturn) return 1;  // NSAlertDefaultReturn
	if (response == NSAlertSecondButtonReturn) return 0;  // NSAlertAlternateReturn
	if (response == NSAlertThirdButtonReturn) return -1;  // NSAlertOtherReturn
	return 1; // default
}

NSInteger NVRunAlertPanel(NSString *title, NSString *msgFormat, NSString *defaultButton, NSString *alternateButton, NSString *otherButton, ...) {
	va_list args;
	va_start(args, otherButton);
	NSString *msg = [[NSString alloc] initWithFormat:msgFormat arguments:args];
	va_end(args);

	NSAlert *alert = [[NSAlert alloc] init];
	if (title) [alert setMessageText:title];
	if (msg) [alert setInformativeText:msg];
	if (defaultButton) [alert addButtonWithTitle:defaultButton];
	if (alternateButton) [alert addButtonWithTitle:alternateButton];
	if (otherButton) [alert addButtonWithTitle:otherButton];

	NSModalResponse response = [alert runModal];
	[msg release];
	[alert release];

	return NVAlertReturnFromResponse(response);
}

NSInteger NVRunCriticalAlertPanel(NSString *title, NSString *msgFormat, NSString *defaultButton, NSString *alternateButton, NSString *otherButton, ...) {
	va_list args;
	va_start(args, otherButton);
	NSString *msg = [[NSString alloc] initWithFormat:msgFormat arguments:args];
	va_end(args);

	NSAlert *alert = [[NSAlert alloc] init];
	[alert setAlertStyle:NSAlertStyleCritical];
	if (title) [alert setMessageText:title];
	if (msg) [alert setInformativeText:msg];
	if (defaultButton) [alert addButtonWithTitle:defaultButton];
	if (alternateButton) [alert addButtonWithTitle:alternateButton];
	if (otherButton) [alert addButtonWithTitle:otherButton];

	NSModalResponse response = [alert runModal];
	[msg release];
	[alert release];

	return NVAlertReturnFromResponse(response);
}

@implementation NSAlert (NVCompat)

+ (NSAlert *)nv_alertWithMessageText:(NSString *)messageTitle
					   defaultButton:(NSString *)defaultButtonTitle
					 alternateButton:(NSString *)alternateButtonTitle
						 otherButton:(NSString *)otherButtonTitle
		   informativeTextWithFormat:(NSString *)informativeText, ... {
	va_list args;
	va_start(args, informativeText);
	NSString *formattedInfo = [[NSString alloc] initWithFormat:informativeText arguments:args];
	va_end(args);

	NSAlert *alert = [[NSAlert alloc] init];
	if (messageTitle) [alert setMessageText:messageTitle];
	if (formattedInfo) [alert setInformativeText:formattedInfo];
	if (defaultButtonTitle) [alert addButtonWithTitle:defaultButtonTitle];
	if (alternateButtonTitle) [alert addButtonWithTitle:alternateButtonTitle];
	if (otherButtonTitle) [alert addButtonWithTitle:otherButtonTitle];

	[formattedInfo release];
	return [alert autorelease];
}

@end
