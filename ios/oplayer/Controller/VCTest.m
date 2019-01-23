//
//  VCTest.m
//  oplayer
//
//  Created by SYALON on 13-12-24.
//
//

#import "VCTest.h"

#import "NativeAppDelegate.h"

@interface VCTest ()
{
    UITableView*    _mainTableView;
    NSArray*        _textArray;
}

@end

@implementation VCTest

- (void)dealloc
{
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _textArray = [[NSArray alloc] initWithObjects:@"test", nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark- TableView delegate method

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_textArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identify = @"vctestview";
    
    UITableViewCellBase* cell = (UITableViewCellBase*)[tableView dequeueReusableCellWithIdentifier:identify];
    if (!cell)
    {
        cell = [[UITableViewCellBase alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    cell.textLabel.text = [_textArray objectAtIndex:indexPath.row];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
