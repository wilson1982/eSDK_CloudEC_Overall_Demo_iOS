//
//  SettingViewController.m
//  EC_SDK_DEMO
//
//  Created by EC Open support team.
//  Copyright(C), 2017, Huawei Tech. Co., Ltd. ALL RIGHTS RESERVED.
//

#import "SettingViewController.h"
#import "CommonUtils.h"

@interface SettingViewController ()
@property (nonatomic, weak)IBOutlet UITextField *serverAddressField;
@property (nonatomic, weak)IBOutlet UITextField *serverPortField;

@end

@implementation SettingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSArray *array = [CommonUtils getUserDefaultValueWithKey:SERVER_CONFIG];
    _serverAddressField.text = array[0];
    _serverPortField.text = array[1];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)saveBtnClicked:(id)sender
{
    [CommonUtils userDefaultSaveValue:@[_serverAddressField.text, _serverPortField.text] forKey:SERVER_CONFIG];
    [self.navigationController popViewControllerAnimated:YES];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
