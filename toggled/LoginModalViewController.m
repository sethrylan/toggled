//
//  Created by Seth Rylan Gainey on 10/14/15.
//  Copyright (c) 2015 Seth Rylan Gainey. All rights reserved.
//
//  See http://stackoverflow.com/questions/16230700/display-uiviewcontroller-as-popup-in-iphone for development hints
//


#import "LoginModalViewController.h"

@interface LoginModalViewController ()

@end

@implementation LoginModalViewController

@synthesize passwordField, emailField;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.view.backgroundColor = [UIColor clearColor];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)okButtonUp:(id)sender {
    [self dismissViewControllerAnimated:YES completion:Nil];
}

// Advance to password field on Done
- (BOOL)textFieldShouldReturn:(UITextField *)theTextField {
    if(theTextField==emailField){
        [passwordField becomeFirstResponder];
    }
    return YES;
}




@end
