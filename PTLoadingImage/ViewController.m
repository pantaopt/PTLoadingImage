//
//  ViewController.m
//  PTLoadingImage
//
//  Created by wkr on 16/7/19.
//  Copyright © 2016年 pantao. All rights reserved.
//

#import "ViewController.h"
#import "UIImageView+WebCache.h"
#import "SDImageCache.h"

@interface ViewController ()<UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageV;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor lightGrayColor];
    
    self.scrollView = [[UIScrollView alloc]initWithFrame:self.view.bounds];
    [self.view addSubview:self.scrollView];
    
    self.imageV = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, 200, 300)];
    self.imageV.center = self.view.center;
    self.imageV.isLoading = YES;
    [self.scrollView addSubview:self.imageV];
    
    self.scrollView.contentSize=self.imageV.frame.size;
    //设置实现缩放
    //设置代理scrollview的代理对象
    self.scrollView.delegate=self;
    //设置最大伸缩比例
    self.scrollView.maximumZoomScale=5.0;
    //设置最小伸缩比例
    self.scrollView.minimumZoomScale=1.0;
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"清空缓存" style:UIBarButtonItemStylePlain target:self action:@selector(clearDisk)];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"加载图片" style:UIBarButtonItemStylePlain target:self action:@selector(downloadImg)];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(doubleTap)];
    tap.numberOfTapsRequired = 2;
    [self.scrollView addGestureRecognizer:tap];
}

- (void)doubleTap{
    if (self.scrollView.zoomScale == 3.0) {
        self.scrollView.zoomScale = 1.0;
    }else{
        self.scrollView.zoomScale = 3.0;
    }
}

- (void)clearDisk{
    [[SDImageCache sharedImageCache]clearMemory];
    [[SDImageCache sharedImageCache]clearDisk];
    self.imageV.image = [UIImage imageNamed:@""];
    [self.imageV setFrame:CGRectMake(0, 0, 200, 300)];
    self.imageV.center = self.view.center;
    [self.imageV removeAll];
}

- (void)downloadImg{
    
    [self.imageV sd_setImageWithURL:[NSURL URLWithString:@"http://img3.duitang.com/uploads/item/201502/19/20150219190717_3hMWH.jpeg"] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        [self.imageV setFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.width*(image.size.height/image.size.width))];
        self.scrollView.contentSize=self.imageV.frame.size;
    }];
    self.imageV.backgroundColor = [UIColor redColor];
}

//告诉scrollview要缩放的是哪个子控件
-(UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.imageV;
}

@end
