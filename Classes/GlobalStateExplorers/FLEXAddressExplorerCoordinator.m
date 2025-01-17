//
//  FLEXAddressExplorerCoordinator.m
//  FLEX
//
//  Created by Tanner Bennett on 7/10/19.
//  Copyright © 2019 Flipboard. All rights reserved.
//

#import "FLEXAddressExplorerCoordinator.h"
#import "FLEXGlobalsTableViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXObjectExplorerViewController.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXUtility.h"

@interface FLEXGlobalsTableViewController (FLEXAddressExploration)
- (void)deselectSelectedRow;
- (void)tryExploreAddress:(NSString *)addressString safely:(BOOL)safely;
@end

@implementation FLEXAddressExplorerCoordinator

#pragma mark - FLEXGlobalsTableViewControllerEntry

+ (NSString *)globalsEntryTitle {
    return @"🔎 Address Explorer";
}

+ (FLEXGlobalsTableViewControllerRowAction)globalsEntryRowAction {
    return ^(FLEXGlobalsTableViewController *host) {
        NSString *title = @"Explore Object at Address";
        NSString *message = @"Paste a hexadecimal address below, starting with '0x'. "
        "Use the unsafe option if you need to bypass pointer validation, "
        "but know that it may crash the app if the address is invalid.";

        UIAlertController *addressInput = [UIAlertController alertControllerWithTitle:title
                                                                              message:message
                                                                       preferredStyle:UIAlertControllerStyleAlert];
        void (^handler)(UIAlertAction *) = ^(UIAlertAction *action) {
            if (action.style == UIAlertActionStyleCancel) {
                [host deselectSelectedRow]; return;
            }
            NSString *address = addressInput.textFields.firstObject.text;
            [host tryExploreAddress:address safely:action.style == UIAlertActionStyleDefault];
        };
        [addressInput addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            NSString *copied = [UIPasteboard generalPasteboard].string;
            textField.placeholder = @"0x00000070deadbeef";
            // Go ahead and paste our clipboard if we have an address copied
            if ([copied hasPrefix:@"0x"]) {
                textField.text = copied;
                [textField selectAll:nil];
            }
        }];
        [addressInput addAction:[UIAlertAction actionWithTitle:@"Explore"
                                                         style:UIAlertActionStyleDefault
                                                       handler:handler]];
        [addressInput addAction:[UIAlertAction actionWithTitle:@"Unsafe Explore"
                                                         style:UIAlertActionStyleDestructive
                                                       handler:handler]];
        [addressInput addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                         style:UIAlertActionStyleCancel
                                                       handler:handler]];
        [host presentViewController:addressInput animated:YES completion:nil];
    };
}

@end

@implementation FLEXGlobalsTableViewController (FLEXAddressExploration)

- (void)deselectSelectedRow {
    NSIndexPath *selected = self.tableView.indexPathForSelectedRow;
    [self.tableView deselectRowAtIndexPath:selected animated:YES];
}

- (void)tryExploreAddress:(NSString *)addressString safely:(BOOL)safely {
    NSScanner *scanner = [NSScanner scannerWithString:addressString];
    unsigned long long hexValue = 0;
    BOOL didParseAddress = [scanner scanHexLongLong:&hexValue];
    const void *pointerValue = (void *)hexValue;

    NSString *error = nil;

    if (didParseAddress) {
        if (safely && ![FLEXRuntimeUtility pointerIsValidObjcObject:pointerValue]) {
            error = @"The given address is unlikely to be a valid object.";
        }
    } else {
        error = @"Malformed address. Make sure it's not too long and starts with '0x'.";
    }

    if (!error) {
        id object = (__bridge id)pointerValue;
        FLEXObjectExplorerViewController *explorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:object];
        [self.navigationController pushViewController:explorer animated:YES];
    } else {
        [FLEXUtility alert:@"Uh-oh" message:error from:self];
        [self deselectSelectedRow];
    }
}

@end
