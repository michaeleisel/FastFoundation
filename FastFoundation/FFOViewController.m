//
//  ViewController.m
//  FastFoundation
//
//  Created by Michael Eisel on 3/30/17.
//  Copyright © 2017 Michael Eisel. All rights reserved.
//

#import "FFOViewController.h"

@interface FFOViewController ()

@end

@implementation FFOViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	UIView *v = [[UIView alloc] initWithFrame:self.view.bounds];
	v.backgroundColor = [UIColor redColor];
	[self.view addSubview:v];
}

@end
