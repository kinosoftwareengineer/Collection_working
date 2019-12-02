//
//  ViewController.m
//  Collection
//
//  Created by kino on 2019/11/14.
//  Copyright © 2019 ShuJuTang. All rights reserved.
//

#import "ViewController.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#include <errno.h>
#import <AVFoundation/AVFoundation.h>
#import "COTime.h"
#import "NSObject+Audio.h"
#import "WavHeader.h"
#import "VidioViewController.h"
#import "MD5String.h"
#import "AFNetworking.h"
#import "XBEchoCancellation.h"


#define SECRET @"123456789"

@interface ViewController ()<AVAudioRecorderDelegate>

//连接按钮，ip按钮，port按钮
//@property (weak, nonatomic) IBOutlet UIButton *reconnectBtn;
@property (weak, nonatomic)  IBOutlet UITextField *IPTextView;
@property (weak, nonatomic)  IBOutlet UITextField *portTextView;
@property (weak, nonatomic)  IBOutlet UIButton *connectBtn;

@property (atomic,assign)    int clinenId;//socekt

@property (nonatomic,assign) int count;//区分已经连接和set-up

@property (nonatomic,strong) NSUUID * myDeviceUUID;//设备UUID
@property (nonatomic,strong) AVAudioRecorder *recorder;

//此下三个属性记录收到的：文件路径，desc描述，sensor ID，将文件路径拆成数组存储用来创建目录和文件
@property (nonatomic,copy)   NSMutableString * filePath;
@property (nonatomic,copy)   NSMutableString * desc;
@property (nonatomic,assign) int  id;
@property (nonatomic,strong) NSMutableArray * fileNameArray;

//储存开始和结束时间的数组
@property (nonatomic,strong) NSMutableArray * timeArrayBegin;
@property (nonatomic,strong) NSMutableArray * timeArrayEnd;

@property (atomic,assign) int  actNumber;//消息序列号

//根据flag去判断有无开始录音和结束
@property (nonatomic,assign) BOOL endFlag;
@property (nonatomic,assign) BOOL startFlag;
@property (nonatomic,assign) BOOL setupFlag;

//传输音频文件的ip和端口号
@property (nonatomic,copy) NSString * fileIP;
@property (nonatomic,copy) NSString * filePort;

//发送准备录音和正在录音的通知
@property (nonatomic,strong)NSNotification * notifiPrepare;
@property (nonatomic,strong) NSNotification * notifirecord;
@property (nonatomic,strong) NSNotification * notifiDismiss;

@property (nonatomic,copy) NSMutableString * ssensor;
@property (nonatomic,copy)NSMutableString * mdString;//录音的32位MD5加密
@property (nonatomic,strong)NSMutableArray * sensorArray;//本机所有的sensor设备
@property (nonatomic,strong)NSMutableArray * timeDateArray;//记录录音和结束时文件的字节数，每次取最后两个对象
@property (nonatomic,copy)  NSMutableString * recordFilePath;
@end

@implementation ViewController

#pragma  mark------------初始化时间数组
-(NSMutableArray *)timeArrayBegin{
    if (_timeArrayBegin==nil){
        NSMutableArray * array=[[NSMutableArray alloc]init];
        _timeArrayBegin=array;
    }
    return _timeArrayBegin;
}
-(NSMutableArray *)timeArrayEnd{
    if (_timeArrayEnd==nil){
        NSMutableArray * array=[[NSMutableArray alloc]init];
        _timeArrayEnd=array;
    }
    return _timeArrayEnd;
}
-(void)viewWillShow{
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendMemoryWarning) name:@"sendMemoryWarning" object:nil];
    
        //基本数据的初始化操作/连接按钮形状/设置初始IP,PORT信息/数组字符串初始化/通知初始化
        self.actNumber=1;
        self.count=0;
        self.id=-1;
    
        self.connectBtn.layer.cornerRadius=5;
        [self.connectBtn.layer masksToBounds];
        
        NSUserDefaults * user=[NSUserDefaults standardUserDefaults];
        NSString * lastIP=[user objectForKey:@"lastIP"];
        if (lastIP){
             self.IPTextView.text=lastIP;
        }
        else{
             self.IPTextView.text=@"192.168.1.103";
        }
        self.portTextView.text=@"8885";
    
        self.IPTextView.enabled=YES;
        self.portTextView.enabled=YES;
       
        self.desc=[NSMutableString string];
        self.filePath=[NSMutableString string];
        self.ssensor=[NSMutableString string];
        self.fileNameArray=[NSMutableArray array];
        self.mdString=[NSMutableString string];
        self.timeDateArray=[NSMutableArray array];
        self.recordFilePath=[NSMutableString string];
        
        self.startFlag=NO;
        self.endFlag=NO;
        self.setupFlag=NO;
        
        NSCharacterSet* set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        self.fileIP=[@"10.10.12.47" stringByTrimmingCharactersInSet:set];
        self.filePort=[@"6134" stringByTrimmingCharactersInSet:set];
        
       self.notifiPrepare=[[NSNotification alloc]initWithName:@"prepare" object:nil userInfo:nil];
       self.notifirecord=[[NSNotification alloc]initWithName:@"record" object:nil userInfo:nil];
       self.notifiDismiss=[[NSNotification alloc]initWithName:@"dismissVC" object:nil userInfo:nil];
    //    self.reconnectBtn.hidden=YES;
        
      
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //请求访问麦克风/设置session/请求网络/降噪
    [self requestForMic];
    [self configSession];
    [self connect];
    [self performSelector:@selector(echo) withObject:nil afterDelay:.01f];
    [self viewWillShow];
}
//降噪
//-(void)echo{
//     [[XBEchoCancellation shared] closeEchoCancellation];
//}
//-(void)setupForPicture{
//
//    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
//    {
//    //第二步:实例化UIImagePickerController对象
//     UIImagePickerController * imagePickerController = [[UIImagePickerController alloc] init];
//
//    //第三步:告诉picker对象是获取相机资源
//    imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
//    //第四步:设置代理
//    imagePickerController.delegate = self;
//    //第五步:设置picker可以编辑
//    imagePickerController.allowsEditing = YES;
//    //第六步:设置进去的模态方式
//    imagePickerController.modalPresentationStyle=UIModalPresentationOverCurrentContext;
//    //第七步:跳转
//    [self presentViewController:imagePickerController animated:YES completion:nil];
//
//    }
////}
//-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
//{
////获取选中资源的类型
//NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
////只能拍照(还有摄像或者二者都可以有的)
//NSString *requiredMediaType = (NSString *)kUTTypeImage;
//if([mediaType isEqualToString:requiredMediaType])
//{
//    UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
//    UIImageWriteToSavedPhotosAlbum(image, self,  @selector(image:didFinishSavingWithError:contextInfo:), nil);
//
//}
//[picker dismissViewControllerAnimated:YES completion:nil];
//}
//
//-(void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
//{
//    [picker dismissViewControllerAnimated:YES completion:nil];
//}
//- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error
//  contextInfo:(void *)contextInfo{
//
//    NSLog(@"saved..");
//}

- (IBAction)endsocketByHand:(UIButton *)sender {
    self.clinenId=-1;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self endSocket];
    });
    sender.hidden=YES;
}

- (void)connect{
    NSURL *url = [NSURL URLWithString:@"http://www.baidu.com"];
    NSURLRequest *request =[NSURLRequest requestWithURL:url];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *sessionDataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
    }];
    [sessionDataTask resume];
}

#pragma  mark------------------配置audiosession信息
-(void)configSession{
    AVAudioSession * audioSession = [AVAudioSession sharedInstance];
       [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
       NSError *activeErr = nil;
       [audioSession setActive:YES error:&activeErr];
       if (activeErr) {
           NSLog(@"active err:%@",activeErr);
       }
}
-(void)closeAudioSession{
    AVAudioSession * audioSession = [AVAudioSession sharedInstance];
       NSError *activeErr = nil;
       [audioSession setActive:NO error:&activeErr];
}
#pragma  mark------------点击开始
- (IBAction)connnection:(UIButton *)sender {
    
    NSCharacterSet* set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString* ip = [self.IPTextView.text stringByTrimmingCharactersInSet:set];
    if (!ip.length) {
        return;
    }
    NSString* portText = [self.portTextView.text stringByTrimmingCharactersInSet:set];
    if (!portText.length) {
        return;
    }
    NSUserDefaults * user=[NSUserDefaults standardUserDefaults];
    [user setObject:self.IPTextView.text forKey:@"lastIP"];
    [user synchronize];
    
    [self createSocket:ip andPort:portText];
}
#pragma  mark------------失败重连重新创建socket，调用连接方法
-(int)connectWhenFaild{
    NSCharacterSet* set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
      NSString* ip = [self.IPTextView.text stringByTrimmingCharactersInSet:set];
      if (!ip.length) {
          return -1;
      }
      NSString* portText = [self.portTextView.text stringByTrimmingCharactersInSet:set];
      if (!portText.length) {
          return -1;
      }
      NSUserDefaults * user=[NSUserDefaults standardUserDefaults];
      [user setObject:self.IPTextView.text forKey:@"lastIP"];
      [user synchronize];
       
       const char * ipC = NULL;
       if ([ip canBeConvertedToEncoding:NSUTF8StringEncoding]) {
           ipC = [ip cStringUsingEncoding:NSUTF8StringEncoding];
       }
       //将port转成数字
       int portNumber=[portText intValue];
         //结构体
       struct sockaddr_in socketAddr;
           socketAddr.sin_family = AF_INET;
           socketAddr.sin_port   = htons(portNumber);
           struct in_addr socketIn_addr;
           socketIn_addr.s_addr  = inet_addr(ipC);
           socketAddr.sin_addr   = socketIn_addr;
       
      int result = connect(self.clinenId, (const struct sockaddr *)&socketAddr, sizeof(socketAddr));
       
       if (result != 0) {
           NSLog(@"连接失败的数值%d---并且对应原因为%s",errno,strerror(errno));
           NSLog(@"连接失败");
           return -1;
           
       }else{
           NSLog(@"重连成功");
           return 1;
          
       }
    
}
#pragma  mark------------创建socket
-(void)createSocket:(NSString *)ip andPort:(NSString *)port{
    int socketID = socket(AF_INET, SOCK_STREAM, 0);
    self.clinenId= socketID;
    if (socketID == -1) {
        NSLog(@"创建socket失败");
    }

    const char * ipC = NULL;
    if ([ip canBeConvertedToEncoding:NSUTF8StringEncoding]) {
        ipC = [ip cStringUsingEncoding:NSUTF8StringEncoding];
    }
    //将port转成数字
    int portNumber=[port intValue];
      //结构体
    struct sockaddr_in socketAddr;
        socketAddr.sin_family = AF_INET;
        socketAddr.sin_port   = htons(portNumber);
        struct in_addr socketIn_addr;
        socketIn_addr.s_addr  = inet_addr(ipC);
        socketAddr.sin_addr   = socketIn_addr;
    
   int result = connect(socketID, (const struct sockaddr *)&socketAddr, sizeof(socketAddr));
    
    if (result != 0) {
        NSLog(@"连接失败的数值%d---并且对应原因为%s",errno,strerror(errno));
        NSLog(@"连接失败");
        [self endSocket];
        
    }else{
        NSLog(@"连接成功");
        [self connectSuccess];
       
    }
}
#pragma  mark------------连接成功调用
-(void)connectSuccess{
    
    self.IPTextView.enabled=NO;
    self.portTextView.enabled=NO;
    self.connectBtn.enabled=NO;
    
    [self.connectBtn setTitle:@"已连接" forState:UIControlStateNormal];
     self.connectBtn.backgroundColor=[UIColor colorWithRed:95/255.0 green:199/255.0 blue:148/255.0 alpha:1];
    [self sendMyDeviceInformation];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self receiveMessage];
    });
    
   
}
#pragma  mark------------收到信息
-(void)receiveMessage{
      while(1){

        //接收数据
            char buffer[1024];
            ssize_t recvLen;
            recvLen = recv((int)self.clinenId, buffer, sizeof(buffer), 0);
          
            if (recvLen==0) continue;
            
            //如果接收数据<0  则判断是否重连
            else if (recvLen<0){
                
                [[NSNotificationCenter defaultCenter]postNotification:self.notifiDismiss];
                if(self.clinenId==-1){
                   
                    return;
                }
//                dispatch_async(dispatch_get_main_queue(), ^{
//
////                    self.reconnectBtn.hidden=NO;
//
//                    while (self.clinenId!=-1) {
//                        [NSThread sleepForTimeInterval:.2f];
//                        NSLog(@"我在尝试重连");
//                        if ([self connectWhenFaild]==1){
//                            [self receiveMessage];
//
//                        }
//                    }
//                });
                 return ;
                }
          
          //接受到了服务端的消息，添加时间和解析数据
           [self.timeArrayBegin addObject:[COTime getTimeStamp]];
           [self.timeArrayEnd   addObject:[COTime getTimeStamp]];
          
            NSData *data = [NSData dataWithBytes:buffer length:recvLen];
            NSError * error=nil;
            id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
            if (error){
                [self senfJSONFaild];
                continue;
            }
          
          //   返回字典才解析，如果返回的内容不是字典，默认忽略
            if ([json isKindOfClass:[NSDictionary class]]) {
                NSDictionary* dict = json;
                NSLog(@"我收到了数据%@",json);
                
                NSString * type = dict[@"secret"];
                NSDictionary * data=[dict objectForKey:@"data"];
                
                //判断秘钥是否正确
                if ([type isEqualToString:SECRET]) {
                    
                    //收到返回的连接成功的数据
                    if (self.count==0){
                        if ([[data objectForKey:@"status"] intValue]==200){
                            NSLog(@"判断后连接成功");
                            self.count=1;
                        }
                    }
                    
                     //收到之后的的数据（包含setup,stat,end）
                    else{
                        NSString * typeSet=[dict objectForKey:@"type"];
                            
                            //收到断开socket的消息
                            if ([typeSet isEqualToString:@"close"]){
                                
                                NSNotification * noto=[NSNotification notificationWithName:@"dismissVC" object:nil];
                                [[NSNotificationCenter defaultCenter]postNotification:noto];
                                if(self.clinenId==-1){
                                    [self sendCloseAgain];
                                    return;
                                }else{
                                    [self.recorder stop];
                                    self.endFlag=YES;
                                    self.startFlag=NO;
                                    [self sendSocketEndMessage];
                                    [self endSocket];
                                    return;
                                }
                            }
                        
                            //setup
                            else if ([typeSet isEqualToString:@"setup"]){
                                
                                NSMutableString * type=[NSMutableString string];
                                NSArray * dataArray=[data objectForKey:@"sensors"];
                                
                                NSDictionary * sensor = dataArray.firstObject;
                                type=[[sensor objectForKey:@"id"] copy];
                                
                                if ([type intValue]==1){
                                    [self sendStatusOK];
                                    if (self.setupFlag==NO){
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            
                                            [self startRecord];
                                            self.setupFlag=YES;
                                            [self changeVC];
                                            [[NSNotificationCenter defaultCenter]postNotification:self.notifiPrepare];
                                         
                                        });
                                    }
                                    else{
                                        NSLog(@"我再次收到了setup指令");//需要做的操作是，停止录音，删除文件，重新调用录音方法
                                        [self.recorder stop];
                                        
                                        //删除文件
                                        NSError * error=nil;
                                        [[NSFileManager defaultManager] removeItemAtPath:self.recorder.url.path error:&error];
                                        if (error){
                                            NSLog(@"再次setup时删除原录音文件失败");
                                        }
                                        else{
                                             NSLog(@"再次setup时删除原录音文件成功");
                                             [self startRecord];
                                        }
                                        
                                    }
                                }
                                else{
                                    [self sendStatusFailed];
                                }
                            }
                            //开始或者是结束
                            else{
                             
                             NSArray *sensorsArray=[data objectForKey:@"content"];
                             for(NSDictionary * sensor in sensorsArray){
                                 NSString * agentID=[sensor objectForKey:@"agentId"];
                                 if ([agentID isEqualToString:self.myDeviceUUID.UUIDString]){
                                     if ([typeSet isEqualToString:@"start"]){
                                         //当已经开始录音但是又收到录音的消息的时候，发送301
                                         if (self.startFlag==YES&&self.endFlag==NO){
                                            [self sendBeginTimeMessageFailed];
                                             
                                            break;
                                         }
                                         
                                         //处理开始录音的数据，将他们变成全局变量
                                         self.ssensor=[data objectForKey:@"sessionId"];
                                         int tempSessionID=[[sensor objectForKey:@"sensorId"] intValue];
                                         
                                         //利用flag去判断返回的sensorID中z是否是我拥有的sensors
                                         int flag;flag=-1;
                                         for (NSNumber * number in self.sensorArray) {
                                             if (tempSessionID==[number intValue]){
                                                 flag=1;
                                                 break;
                                             }
                                         }
                                         if (flag==-1){
                                             [self sendSessorUnknow];
                                             break;
                                         }
                                         
                                         self.id=tempSessionID;
                                         self.filePath=[[[sensor objectForKey:@"filepath"] stringByRemovingPercentEncoding]copy];
                                         self.desc=[[[data objectForKey:@"desc"] stringByRemovingPercentEncoding] copy];
                    
                                         [self markDataLength];
                                         dispatch_async(dispatch_get_main_queue(), ^{
                                              [[NSNotificationCenter defaultCenter]postNotification:self.notifirecord];
                                         });
                                        
                                         self.startFlag=YES;
                                         self.endFlag=NO;
                                     
                                     
                                     }
                                     else if([typeSet isEqualToString:@"end"]) {
                                         if (self.endFlag==YES){
                                             [self sendBeginTimeMessageFailed];
                                             break;
                                         }
                                      
                                         if (self.startFlag==YES){
                                              [self stopRecord];
                                              self.endFlag=YES;
                                              self.startFlag=NO;
                                         }
                                        
                                         dispatch_async(dispatch_get_main_queue(), ^{
                                            [[NSNotificationCenter defaultCenter]postNotification:self.notifiPrepare];
                                         });
                                         break;
                                     }
                                     else{
                                       //如果收到除了start，end的消息外，默认不操作
                                     }
                                 }
                             
                             }
                             if (self.id==-1){
                                NSLog(@"没有我的设备");
                            }
                         }
                    }
                }
                else{
                    NSLog(@"secret错误!");
                    [self sendSecretWrong];
                }
            }
    }
    
}
#pragma  mark-----------发送开始停止成功/失败消息
-(void)sendBeginTimeMessage{
    NSString * start1=self.timeArrayBegin[self.timeArrayBegin.count-3];
    NSString * start2=self.timeArrayBegin[self.timeArrayBegin.count-2];
    NSString * start3=self.timeArrayBegin[self.timeArrayBegin.count-1];
    
    NSString * startSub1=[start1 substringFromIndex:4];
    NSString * startSub3=[start3 substringFromIndex:4];
    
    long long intstart1=[startSub1 longLongValue];
    long long intstart3=[startSub3 longLongValue];
    
    NSDictionary *contentItem=@{@"agentId": self.myDeviceUUID.UUIDString,
                         @"sensorId": [NSString stringWithFormat:@"%d",self.id],
                         @"filepath": self.filePath,
                         @"begin": start1,
                         @"beforeCall": start2,
                         @"afterCall": start3,
                         @"offset":@(intstart3-intstart1) };
    
    
    NSDictionary * extra=@{@"desc":self.desc,
                           @"sessionId":@"S0001",
                           @"content":@[contentItem]};
    
    NSDictionary * data=@{@"status": @200,
                         @"message": @"OK",
                         @"agentId": self.myDeviceUUID.UUIDString,
                          @"extra":extra};
    NSDictionary * dic=@{@"type": @"ack-start",
                         @"operationId": [NSNumber numberWithInt:++self.actNumber],
                         @"secret": SECRET,
                         @"data":data};

    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self sendMsgAction:json];
    NSLog(@"self.timeArrayBegin===%@",self.timeArrayBegin);
}
//目前用不到
-(void)sendBeginTimeMessageFailed{
    NSDictionary * data=@{@"status": @301,
                          @"message": @"Sensor lost",
                          @"agentId": self.myDeviceUUID.UUIDString};
    NSDictionary * dic=@{@"type": @"ack-start",
                         @"operationId": [NSNumber numberWithInt:++self.actNumber],
                         @"secret":SECRET,
                         @"data":data};
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self sendMsgAction:json];
}
-(void)sendStopTimeMessage{
       NSString * end1=self.timeArrayEnd[self.timeArrayBegin.count-3];
       NSString * end2=self.timeArrayEnd[self.timeArrayBegin.count-2];
       NSString * end3=self.timeArrayEnd[self.timeArrayBegin.count-1];
    
       NSString * endSub1=[end1 substringFromIndex:4];
       NSString * endSub3=[end3 substringFromIndex:4];
       
       long long intend1=[endSub1 longLongValue];
       long long intend3=[endSub3 longLongValue];
    
    NSDictionary *contentItem=@{@"agentId": self.myDeviceUUID.UUIDString,
                               @"sensorId": [NSString stringWithFormat:@"%d",self.id],
                               @"filepath": self.filePath,
                               @"begin": end1,
                               @"beforeCall": end2,
                               @"afterCall": end3,
                               @"offset": @(intend3-intend1)};
       
    NSDictionary * extra=@{@"desc":self.desc,
                          @"sessionId":self.ssensor,
                           @"content":@[contentItem]};
       
    NSDictionary * data=@{@"status": @200,
                         @"message": @"OK",
                         @"agentId": self.myDeviceUUID.UUIDString,
                         @"extra":extra};
    
    NSDictionary * dic=@{@"type": @"ack-end",
                        @"operationId": [NSNumber numberWithInt:++self.actNumber],
                        @"secret": SECRET,
                        @"data":data};

    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self sendMsgAction:json];
NSLog(@"$$$$%@",self.timeArrayEnd);
}
-(void)sendStopTimeMessageFailed{
    NSDictionary * data=@{ @"status": [NSNumber numberWithInt:++self.actNumber],
                          @"message": @"No space",
                          @"agentId": self.myDeviceUUID.UUIDString};

    NSDictionary * dic=@{ @"type": @"ack-end",
                         @"operationId": [NSNumber numberWithInt:++self.actNumber],
                         @"secret":SECRET,
                         @"data":data};

    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self sendMsgAction:json];
}

#pragma  mark-----------开始录制停止方法
-(void)startRecord{
   
    NSString *tempPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"parent.wav"];
           NSLog(@"储存文件的路径%@",tempPath);
           NSURL *tmpRecordURL = [NSURL fileURLWithPath:tempPath];
           [self.fileNameArray addObject:tempPath];
           NSDictionary *recordSetting = @{AVSampleRateKey: @(16000.),
                                           AVFormatIDKey: @(kAudioFormatLinearPCM),
                                           AVLinearPCMBitDepthKey: @(16),
                                           AVNumberOfChannelsKey: @(1),
                                           AVLinearPCMIsBigEndianKey: @(NO),
                                           AVLinearPCMIsFloatKey: @(NO),
                                           };
           self.recorder= nil;
           self.recorder = [[AVAudioRecorder alloc]initWithURL:tmpRecordURL settings:recordSetting error:nil];
           self.recorder.delegate = self;
           [self.recorder prepareToRecord];
           [self.recorder setMeteringEnabled:YES];
           [self.recorder record];
          

}
-(void)markDataLength{
    [self.timeArrayBegin addObject:[COTime getTimeStamp]];
    NSMutableData *targetData = [NSMutableData dataWithContentsOfFile:self.recorder.url.path];
    [self.timeDateArray addObject:[NSNumber numberWithInteger:targetData.length]];
    NSLog(@"我是开始时截取到的长度%@",[NSNumber numberWithInteger:targetData.length]);
    [self.timeArrayBegin addObject:[COTime getTimeStamp]];
    [self sendBeginTimeMessage];
}
-(void)changeVC{
    dispatch_async(dispatch_get_main_queue(), ^{
           VidioViewController * videoVC=[[VidioViewController alloc]init];
           videoVC.modalPresentationStyle=UIModalPresentationFullScreen;
           [self presentViewController:videoVC animated:YES completion:nil];
        });
 
}
-(void)stopRecord{
    
    NSURL *tmpURL = self.recorder.url;
    if (!tmpURL) {
        NSLog(@"未录制成功");
        [self sendStopTimeMessageFailed];
        return;
    }
    
    [self.timeArrayEnd addObject:[COTime getTimeStamp]];
    NSMutableData *targetData = [NSMutableData dataWithContentsOfFile:self.recorder.url.path];
    [self.timeDateArray addObject:[NSNumber numberWithInteger:targetData.length]];
    [self.timeArrayEnd addObject:[COTime getTimeStamp]];
    
    NSLog(@"我是结束时截取到的长度%@",[NSNumber numberWithInteger:targetData.length]);
    NSLog(@"储存文件的路径%@",self.recorder.url.path);
    
    //获取结束时的data文件
    NSMutableData * endData=[NSMutableData dataWithContentsOfFile:self.recorder.url.path];
    //记录开始和结束时的字节数，生成一个NSRange,获取截取后的二进制文件
    
    int beginStamp=[self.timeDateArray[self.timeDateArray.count-2] intValue];
    int endStamp=[self.timeDateArray[self.timeDateArray.count-1] intValue];
    
    NSMutableData * resultData=[NSMutableData data];
    NSRange  range=NSMakeRange(beginStamp, endStamp-beginStamp);
    NSData * dataCut=[endData subdataWithRange:range];
    
    NSData *header = WriteWavFileHeader(dataCut.length,dataCut.length + 36,16000,1,32000);
    //拼成wav文件
    [resultData appendData:header];
    [resultData appendData:dataCut];

    NSString * string=[[NSString alloc]initWithData:resultData encoding:NSASCIIStringEncoding];
    self.mdString=[[MD5String MD5ForUpper32Bate:string] copy];
    [self sendStopTimeMessage];
    
    //根据resultData重新生成一个文件
    
    NSFileManager * manager=[NSFileManager defaultManager];
    NSString * home=NSHomeDirectory();
    NSMutableArray * arrayFull=[[self.filePath componentsSeparatedByString:@"/"] copy];
    NSMutableString * documentString=[NSMutableString string];
    for (int i=0;i<arrayFull.count-1;i++) {
        documentString=[[documentString stringByAppendingPathComponent:arrayFull[i]] copy];
    }
    home=[home stringByAppendingPathComponent:@"Documents"];
    NSString * pathResultDocument=[home stringByAppendingPathComponent:documentString];
    [manager createDirectoryAtPath:pathResultDocument withIntermediateDirectories:YES attributes:nil error:nil];
    BOOL createSucees=[manager createFileAtPath:[pathResultDocument stringByAppendingPathComponent:arrayFull.lastObject]  contents:resultData attributes:nil];
    if (createSucees){
        NSLog(@"写入文件成功，路径为%@",[pathResultDocument stringByAppendingPathComponent:arrayFull.lastObject] );
    }
    else{
        NSLog(@"写入文件失败");
    }
    NSLog(@"resultData.length%lu",(unsigned long)resultData.length);
    //发送截取好的wav语音文件
    [self sendFile];
}
//拼接wav头文件函数
NSData* WriteWavFileHeader(long totalAudioLen, long totalDataLen, long longSampleRate,int channels, long byteRate)
{
    Byte  header[44];
    header[0] = 'R';  // RIFF/WAVE header
    header[1] = 'I';
    header[2] = 'F';
    header[3] = 'F';
    header[4] = (Byte) (totalDataLen & 0xff);  //file-size (equals file-size - 8)
    header[5] = (Byte) ((totalDataLen >> 8) & 0xff);
    header[6] = (Byte) ((totalDataLen >> 16) & 0xff);
    header[7] = (Byte) ((totalDataLen >> 24) & 0xff);
    header[8] = 'W';  // Mark it as type "WAVE"
    header[9] = 'A';
    header[10] = 'V';
    header[11] = 'E';
    header[12] = 'f';  // Mark the format section 'fmt ' chunk
    header[13] = 'm';
    header[14] = 't';
    header[15] = ' ';
    header[16] = 16;   // 4 bytes: size of 'fmt ' chunk, Length of format data.  Always 16
    header[17] = 0;
    header[18] = 0;
    header[19] = 0;
    header[20] = 1;  // format = 1 ,Wave type PCM
    header[21] = 0;
    header[22] = (Byte) channels;  // channels
    header[23] = 0;
    header[24] = (Byte) (longSampleRate & 0xff);
    header[25] = (Byte) ((longSampleRate >> 8) & 0xff);
    header[26] = (Byte) ((longSampleRate >> 16) & 0xff);
    header[27] = (Byte) ((longSampleRate >> 24) & 0xff);
    header[28] = (Byte) (byteRate & 0xff);
    header[29] = (Byte) ((byteRate >> 8) & 0xff);
    header[30] = (Byte) ((byteRate >> 16) & 0xff);
    header[31] = (Byte) ((byteRate >> 24) & 0xff);
    header[32] = (Byte) (1 * 16 / 8); // block align
    header[33] = 0;
    header[34] = 16; // bits per sample
    header[35] = 0;
    header[36] = 'd'; //"data" marker
    header[37] = 'a';
    header[38] = 't';
    header[39] = 'a';
    header[40] = (Byte) (totalAudioLen & 0xff);  //data-size (equals file-size - 44).
    header[41] = (Byte) ((totalAudioLen >> 8) & 0xff);
    header[42] = (Byte) ((totalAudioLen >> 16) & 0xff);
    header[43] = (Byte) ((totalAudioLen >> 24) & 0xff);
    return [[NSData alloc] initWithBytes:header length:44];;
}

#pragma ----发送文件
-(void)sendFile{

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    [manager POST:@"http://10.10.12.47:6134" parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        
          [formData appendPartWithFormData:[@"method" dataUsingEncoding:NSUTF8StringEncoding] name:@"POST"];
          [formData appendPartWithFormData:[SECRET dataUsingEncoding:NSUTF8StringEncoding] name:@"secret"];
          [formData appendPartWithFormData:[self.mdString dataUsingEncoding:NSUTF8StringEncoding] name:@"md5"];
        
          NSDictionary * dic=@{@"agentId":self.myDeviceUUID.UUIDString,
                               @"sensorId": [NSString stringWithFormat:@"%d",self.id],
                               @"operationId":[NSNumber numberWithInt:++self.actNumber],
                               @"filename":self.filePath
            
          };
         NSData * data=[NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
          [formData appendPartWithFormData:data name:@"info"];
          [formData appendPartWithFileURL:[NSURL URLWithString:self.recordFilePath] name:self.filePath error:nil];

    } progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {

    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"发送错误%@",error);
    }];
    
    NSLog(@"发送文件成功");
}
#pragma  mark-----------准备前状态
-(void)sendStatusOK{
    NSDictionary * data=@{ @"status":@200,
                          @"message":@"ok",
                          @"agentId":self.myDeviceUUID.UUIDString};

    NSDictionary * dic=@{ @"type":@"ack-setup",
                         @"operationId":[NSNumber numberWithInt:++self.actNumber],
                         @"secret":SECRET,
                         @"data":data};
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self sendMsgAction:json];

}
//目前用不到
-(void)sendStatusFailed{
      
    NSDictionary * sensors=@{ @"id":@1,
                             @"status":@300,
                             @"message":@"Unable to record"};
    
    NSDictionary * data=@{@"message":@"Unknown spec",
                         @"agentId":self.myDeviceUUID.UUIDString,
                          @"sensors":@[sensors]};
    
    NSDictionary * dic=@{@"type":@"ack-setup",
                        @"operationId":[NSNumber numberWithInt:++self.actNumber],
                        @"status":@"300",
                        @"secret":SECRET,
                        @"data":data};
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self sendMsgAction:json];
}
#pragma mark ------------发送设备信息
-(void)sendMyDeviceInformation{

     NSDictionary *recordSetting = @{AVSampleRateKey: @(44100),
                                    AVFormatIDKey: @(kAudioFormatLinearPCM),
                                    AVLinearPCMBitDepthKey: @(16),
                                    AVNumberOfChannelsKey: @(1),
                                    AVLinearPCMIsBigEndianKey: @(NO),
                                    AVLinearPCMIsFloatKey: @(NO)};
    
    NSDictionary * sensor1=@{@"name":@"micphone",
                            @"type":@"mic",
                            @"id": @1,
                            @"desc":@"micphone1",
                            @"spec":recordSetting};

    NSDictionary * sensor2=@{@"name":@"video",
                           @"type":@"camera",
                           @"id": @2,
                           @"desc":@"video2",
                           @"spec":recordSetting};
    self.sensorArray=[NSMutableArray array];
    [self.sensorArray addObject:@1];
    [self.sensorArray addObject:@2];

                            
    
    NSString * name=[[UIDevice currentDevice] name];
    self.myDeviceUUID=[[UIDevice currentDevice] identifierForVendor];
    NSDictionary * data=@{@"name":name,
                          @"agentId":self.myDeviceUUID.UUIDString,
                          @"sensors":@[sensor1,sensor2]};
    
    NSDictionary * dic=@{@"type":@"open",
                         @"operationId":[NSNumber numberWithInt:self.actNumber],
                         @"secret":SECRET,
                         @"data":data};

   
   NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
   NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self sendMsgAction:json];
   
    
}
-(void)sendCloseAgain{
    NSDictionary * data=@{@"status": @303,
                         @"message": @"Closed already",
                         @"agentId": self.myDeviceUUID.UUIDString,};
    NSDictionary * dic=@{@"type": @"ack-close",
                        @"secret": SECRET,
                        @"operationId": [NSNumber numberWithInt:++self.actNumber],
                        @"data": data};
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
      NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self sendMsgAction:json];
}
-(void)sendSocketEndMessage{
    NSDictionary * data=@{@"status": @200,
                         @"message": @"OK",
                         @"agentId": self.myDeviceUUID.UUIDString};
                                
    NSDictionary * dic=@{@"type": @"ack-close",
                        @"secret":SECRET,
                        @"operationId": [NSNumber numberWithInt:++self.actNumber],
                        @"data": data};
NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
  NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self sendMsgAction:json];
}

-(void)sendSecretWrong{
    NSDictionary * dic=@{@"status":@401,
                        @"message":@"Invaild Secret"};
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self sendMsgAction:json];

}
-(void)senfJSONFaild{
    NSDictionary * dic=@{@"status":@402,
                        @"message":@"Invalid Request",
                        @"error":@"Unknown field"
};
      NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
      NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
      [self sendMsgAction:json];
}
-(void)sendMemoryWarning{
    NSDictionary * dic=@{@"status": @304,
        @"message": @"No Space"};
     NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
     NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
     [self sendMsgAction:json];
     exit(0);
}
-(void)sendSessorUnknow{
    NSDictionary * dic=@{@"status":@303,
        @"message":@"Unknown Sensor"};
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
   [self sendMsgAction:json];

}
#pragma mark ---------发送数据
- (void)sendMsgAction:(NSString *)json{
    NSLog(@"我已经发送的数据%@",json);
    const char *msg = json.UTF8String;
    send((int)self.clinenId,msg, strlen(msg), 0);
    
  
}
#pragma mark ---------请求麦克风
-(void)requestForMic{
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (granted) {
            
        }
        else{
            UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"麦克风权限未开启" message:@"麦克风权限未开启，请进入系统【设置】>【隐私】>【麦克风】中打开开关,开启麦克风功能" preferredStyle:UIAlertControllerStyleAlert];
               UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {

               }];
               UIAlertAction *setAction = [UIAlertAction actionWithTitle:@"去设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                   //跳入当前App设置界面
                    NSURL* url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                   if (@available(iOS 10.0, *)) {
                       [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
                   } else {
                       [[UIApplication sharedApplication]openURL:url];
                   }
               }];
               [alertVC addAction:cancelAction];
               [alertVC addAction:setAction];

               [self presentViewController:alertVC animated:YES completion:nil];
           }
    }];
}
#pragma mark ---------socket关闭
-(void)endSocket{
    self.IPTextView.enabled=YES;
    self.portTextView.enabled=YES;
    if ([self.recorder isRecording]){
         [self.recorder stop];
    }
    [self closeAudioSession];
    dispatch_async(dispatch_get_main_queue(), ^{
        
          [self.connectBtn setTitle:@"重新请求连接" forState:UIControlStateNormal];
          self.connectBtn.backgroundColor=[UIColor colorWithRed:176/255.0 green:188/255.0 blue:214/255.0152 alpha:1];
          self.clinenId=-1;
          self.connectBtn.enabled=YES;
          self.count=0;
          self.setupFlag=NO;
      
        NSFileManager * manager=[NSFileManager defaultManager];
        if ([manager fileExistsAtPath:self.recorder.url.path]){
           [[NSFileManager defaultManager] removeItemAtPath:self.recorder.url.path error:nil];
        }

    });
}
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [self.IPTextView resignFirstResponder];
    [self.portTextView resignFirstResponder];
}
@end
