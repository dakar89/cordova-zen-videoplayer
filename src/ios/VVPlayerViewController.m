//
//  VVPlayerViewController.m
//  VodVision
//
//  Created by Daniel Karlsson on 08/06/16.
//
//

#import "VVPlayerViewController.h"

@implementation VVPlayerViewController

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
//    NSLog(@"VVPlayerViewController: viewWillDisappear");
    
    [[NSNotificationCenter defaultCenter] postNotificationName:VVPlayerViewDidDisappearNotification object:nil];
}
@end
