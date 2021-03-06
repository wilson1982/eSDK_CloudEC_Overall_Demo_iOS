//
//  MembersViewController.m
//  EC_SDK_DEMO
//
//  Created by EC Open support team.
//  Copyright(C), 2017, Huawei Tech. Co., Ltd. ALL RIGHTS RESERVED.
//

#import "MembersViewController.h"
#import "ContactListCell.h"
#import <TUPIOSSDK/TUPIOSSDK.h>
#import <TUPIOSSDK/GroupEntity.h>
#import <TUPContactSDK/GroupEntity+ServiceObject.h>
#import "PersonDetailViewController.h"
#import "CreateGroupController.h"
#import <TUPIOSSDK/ECSAppConfig.h>

@interface MembersViewController ()

@end

@implementation MembersViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Members";
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc]initWithTitle:@"Add" style:UIBarButtonItemStylePlain target:self action:@selector(onAddGroupMemberBtnAction)];
    self.navigationItem.rightBarButtonItem = addButton;
    addButton.enabled = NO;
    if ([self isGroupManager]) {
        addButton.enabled = YES;
    }
    [self.tableView registerNib:[UINib nibWithNibName:@"ContactListCell" bundle:nil] forCellReuseIdentifier:@"ContactListCell"];
    [self.group addObserver:self forKeyPath:@"members" options:NSKeyValueObservingOptionNew context:NULL];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)dealloc
{
    [self.group removeObserver:self forKeyPath:@"members"];
}

/**
 This method is used to jump to CreateGroupController
 */
-(void)onAddGroupMemberBtnAction
{
    CreateGroupController *createCtrl = [[CreateGroupController alloc]init];
    createCtrl.currentGroup = self.group;
    createCtrl.createGroupType = ADD_USER;
    [self.navigationController pushViewController:createCtrl animated:YES];
}

/**
 This method is used to kick group member

 @param row row
 */
-(void)handleMemberTableWithRow:(NSInteger)row
{
    if (![self isGroupManager])
    {
        [self showMessage:@"You are not the owner!"];
        return;
    }
    EmployeeEntity *groupMember = [[self.group.members allObjects] objectAtIndex:row];
    if ([groupMember.contactId length] >0 )
    {
        if ([groupMember.contactId isEqualToString:_group.ownerId])
        {
            [self showMessage:@"Cannot delete the owner!"];
            return;
        }
        [_group kickUsers:@[groupMember.contactId] completion:^(NSError *error)
         {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (error)
                 {
                     [self showMessage:@"Delete failed!"];
                 }
                 else
                 {
                     [self.tableView reloadData];
                 }
             });
         }];
    }
}

/**
 This method is used to judge is group manager or not

 @return is group manager or not
 */
-(BOOL)isGroupManager
{
    return [[ECSAppConfig sharedInstance].latestAccount isEqualToString:self.group.ownerId];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    
    return [self.group.members allObjects].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ContactListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ContactListCell" forIndexPath:indexPath];
    cell.person = ([self.group.members allObjects])[indexPath.row];
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    PersonDetailViewController *personDetailCtrl = [[PersonDetailViewController alloc]initWithPerson:([self.group.members allObjects])[indexPath.row]];
    [self.navigationController pushViewController:personDetailCtrl animated:YES];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isGroupManager]) {
        return YES;
    }
    return NO;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self handleMemberTableWithRow:indexPath.row];
    }
}

#pragma mark
#pragma mark
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    [self.tableView reloadData];
}

#pragma mark
#pragma mark --- AlertShow ---
-(void)showMessage:(NSString *)msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:NO completion:nil];
    [NSTimer scheduledTimerWithTimeInterval:0.5
                                     target:self
                                   selector:@selector(creatAlert:)
                                   userInfo:alert
                                    repeats:NO];
}

- (void)creatAlert:(NSTimer *)timer {
    UIAlertController *alert = [timer userInfo];
    [alert dismissViewControllerAnimated:YES completion:nil];
    alert = nil;
}

@end
