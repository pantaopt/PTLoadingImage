/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImageView+WebCache.h"
#import "objc/runtime.h"
#import "UIView+WebCacheOperation.h"

static char imageURLKey;
static char TAG_ACTIVITY_INDICATOR;
static char TAG_ACTIVITY_STYLE;
static char TAG_ACTIVITY_SHOW;

@implementation UIImageView (WebCache)

- (void)sd_setImageWithURL:(NSURL *)url {
    [self sd_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:nil];
}

- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:nil];
}

- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:nil];
}

- (void)sd_setImageWithURL:(NSURL *)url completed:(SDWebImageCompletionBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:completedBlock];
}

- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder completed:(SDWebImageCompletionBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:completedBlock];
}

- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options completed:(SDWebImageCompletionBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:completedBlock];
}

- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options progress:(SDWebImageDownloaderProgressBlock)progressBlock completed:(SDWebImageCompletionBlock)completedBlock {
    [self sd_cancelCurrentImageLoad];
    objc_setAssociatedObject(self, &imageURLKey, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (!(options & SDWebImageDelayPlaceholder)) {
        dispatch_main_async_safe(^{
            self.image = placeholder;
        });
    }
    
    if (url) {

        // check if activityView is enabled or not
        if ([self showActivityIndicatorView]) {
            [self addActivityIndicator];
        }

        __weak __typeof(self)wself = self;
        id <SDWebImageOperation> operation = [SDWebImageManager.sharedManager downloadImageWithURL:url options:options progress:^(NSInteger receivedSize, NSInteger expectedSize, float ratio) {
            if (wself.isLoading) {
//                [wself addRatioProgress];
                [wself addProgress];
                [wself showAnimationFromValue:[NSNumber numberWithFloat:self.lastRatio] toValue:[NSNumber numberWithFloat:ratio]];
                self.lastRatio = ratio;
                NSString *ratioStr = [NSString stringWithFormat:@"%.f",[[NSString stringWithFormat:@"%.2f",ratio] floatValue]*100];
                wself.ratioProgress.text = [ratioStr stringByAppendingString:@"%"];
            }
        } completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            [wself removeActivityIndicator];
            if (!wself) return;
            dispatch_main_sync_safe(^{
                if (!wself) return;
                if (image && (options & SDWebImageAvoidAutoSetImage) && completedBlock)
                {
                    completedBlock(image, error, cacheType, url);
                    return;
                }
                else if (image) {
                    wself.image = image;
                    [wself setNeedsLayout];
                } else {
                    if ((options & SDWebImageDelayPlaceholder)) {
                        wself.image = placeholder;
                        [wself setNeedsLayout];
                    }
                }
                if (completedBlock && finished) {
                    if (wself.isLoading) {
                        [wself showAnimationFromValue:[NSNumber numberWithFloat:0.0f] toValue:[NSNumber numberWithFloat:1.0]];
                        [wself removeAll];
                    }
                    completedBlock(image, error, cacheType, url);
                }
            });
        }];
        [self sd_setImageLoadOperation:operation forKey:@"UIImageViewImageLoad"];
    } else {
        dispatch_main_async_safe(^{
            [self removeActivityIndicator];
            if (completedBlock) {
                NSError *error = [NSError errorWithDomain:SDWebImageErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Trying to load a nil url"}];
                completedBlock(nil, error, SDImageCacheTypeNone, url);
            }
        });
    }
}

- (void)sd_setImageWithPreviousCachedImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options progress:(SDWebImageDownloaderProgressBlock)progressBlock completed:(SDWebImageCompletionBlock)completedBlock {
    NSString *key = [[SDWebImageManager sharedManager] cacheKeyForURL:url];
    UIImage *lastPreviousCachedImage = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:key];
    
    [self sd_setImageWithURL:url placeholderImage:lastPreviousCachedImage ?: placeholder options:options progress:progressBlock completed:completedBlock];    
}

- (NSURL *)sd_imageURL {
    return objc_getAssociatedObject(self, &imageURLKey);
}

- (void)sd_setAnimationImagesWithURLs:(NSArray *)arrayOfURLs {
    [self sd_cancelCurrentAnimationImagesLoad];
    __weak __typeof(self)wself = self;

    NSMutableArray *operationsArray = [[NSMutableArray alloc] init];

    for (NSURL *logoImageURL in arrayOfURLs) {
        id <SDWebImageOperation> operation = [SDWebImageManager.sharedManager downloadImageWithURL:logoImageURL options:0 progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            if (!wself) return;
            dispatch_main_sync_safe(^{
                __strong UIImageView *sself = wself;
                [sself stopAnimating];
                if (sself && image) {
                    NSMutableArray *currentImages = [[sself animationImages] mutableCopy];
                    if (!currentImages) {
                        currentImages = [[NSMutableArray alloc] init];
                    }
                    [currentImages addObject:image];

                    sself.animationImages = currentImages;
                    [sself setNeedsLayout];
                }
                [sself startAnimating];
            });
        }];
        [operationsArray addObject:operation];
    }

    [self sd_setImageLoadOperation:[NSArray arrayWithArray:operationsArray] forKey:@"UIImageViewAnimationImages"];
}

- (void)sd_cancelCurrentImageLoad {
    [self sd_cancelImageLoadOperationWithKey:@"UIImageViewImageLoad"];
}

- (void)sd_cancelCurrentAnimationImagesLoad {
    [self sd_cancelImageLoadOperationWithKey:@"UIImageViewAnimationImages"];
}


#pragma mark -
- (UIActivityIndicatorView *)activityIndicator {
    return (UIActivityIndicatorView *)objc_getAssociatedObject(self, &TAG_ACTIVITY_INDICATOR);
}

- (void)setActivityIndicator:(UIActivityIndicatorView *)activityIndicator {
    objc_setAssociatedObject(self, &TAG_ACTIVITY_INDICATOR, activityIndicator, OBJC_ASSOCIATION_RETAIN);
}

- (void)setShowActivityIndicatorView:(BOOL)show{
    objc_setAssociatedObject(self, &TAG_ACTIVITY_SHOW, [NSNumber numberWithBool:show], OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)showActivityIndicatorView{
    return [objc_getAssociatedObject(self, &TAG_ACTIVITY_SHOW) boolValue];
}

- (void)setIndicatorStyle:(UIActivityIndicatorViewStyle)style{
    objc_setAssociatedObject(self, &TAG_ACTIVITY_STYLE, [NSNumber numberWithInt:style], OBJC_ASSOCIATION_RETAIN);
}

- (int)getIndicatorStyle{
    return [objc_getAssociatedObject(self, &TAG_ACTIVITY_STYLE) intValue];
}

- (void)addActivityIndicator {
    if (!self.activityIndicator) {
        self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:[self getIndicatorStyle]];
        self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;

        dispatch_main_async_safe(^{
            [self addSubview:self.activityIndicator];

            [self addConstraint:[NSLayoutConstraint constraintWithItem:self.activityIndicator
                                                             attribute:NSLayoutAttributeCenterX
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self
                                                             attribute:NSLayoutAttributeCenterX
                                                            multiplier:1.0
                                                              constant:0.0]];
            [self addConstraint:[NSLayoutConstraint constraintWithItem:self.activityIndicator
                                                             attribute:NSLayoutAttributeCenterY
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self
                                                             attribute:NSLayoutAttributeCenterY
                                                            multiplier:1.0
                                                              constant:0.0]];
        });
    }

    dispatch_main_async_safe(^{
        [self.activityIndicator startAnimating];
    });

}

- (void)removeActivityIndicator {
    if (self.activityIndicator) {
        [self.activityIndicator removeFromSuperview];
        self.activityIndicator = nil;
    }
}

- (UILabel *)ratioProgress{
    return objc_getAssociatedObject(self, @selector(ratioProgress));
}

- (void)setRatioProgress:(UILabel *)ratioProgress{
    objc_setAssociatedObject(self, @selector(ratioProgress), ratioProgress, OBJC_ASSOCIATION_RETAIN);
}

- (void)addRatioProgress{
    if (!self.ratioProgress) {
        self.ratioProgress = [[UILabel alloc]initWithFrame:self.bounds];
        self.ratioProgress.textColor = [UIColor redColor];
        self.ratioProgress.font = [UIFont systemFontOfSize:30*([UIScreen mainScreen].bounds.size.width/375)];
        self.ratioProgress.backgroundColor = [UIColor clearColor];
        self.ratioProgress.textAlignment = NSTextAlignmentCenter;
        dispatch_main_async_safe(^{
            if (![self.ratioProgress.superview isEqual:self]) {
                [self addSubview:self.ratioProgress];
            }
        });
    }
}

- (UIView *)progress{
    return objc_getAssociatedObject(self, @selector(progress));
}

- (void)setProgress:(UIView *)progress{
    objc_setAssociatedObject(self, @selector(progress), progress, OBJC_ASSOCIATION_RETAIN);
}

- (void)addProgress{
    if (!self.progress) {
        self.progress = [[UIView alloc]initWithFrame:CGRectMake(self.frame.size.width*3/8, self.frame.size.height/2-self.frame.size.width/8, self.frame.size.width/4, self.frame.size.width/4)];
        self.progress.backgroundColor = [UIColor colorWithRed:1.00f green:1.00f blue:1.00f alpha:0.60f];
        self.progress.layer.cornerRadius = self.frame.size.width/8;
        dispatch_main_async_safe(^{
            if (![self.progress.superview isEqual:self]) {
                [self addSubview:self.progress];
            }
        });
    }
}

- (CABasicAnimation *)pathAniamtion{
    return objc_getAssociatedObject(self, @selector(pathAniamtion));
}

- (void)setPathAniamtion:(CABasicAnimation *)pathAniamtion{
    objc_setAssociatedObject(self, @selector(pathAniamtion), pathAniamtion, OBJC_ASSOCIATION_RETAIN);
}

- (CAShapeLayer *)shapeLayer{
    return objc_getAssociatedObject(self, @selector(shapeLayer));
}

- (void)setShapeLayer:(CAShapeLayer *)shapeLayer{
    objc_setAssociatedObject(self, @selector(shapeLayer), shapeLayer, OBJC_ASSOCIATION_RETAIN);
}

- (void)showAnimationFromValue:(NSNumber *)fromValue toValue:(NSNumber *)toValue{
    if (!self.shapeLayer) {
        self.shapeLayer=[CAShapeLayer layer];
        [self.progress.layer addSublayer:self.shapeLayer];
        self.shapeLayer.fillColor=[UIColor colorWithRed:1.00f green:1.00f blue:1.00f alpha:0.60f].CGColor;//填充颜色
        self.shapeLayer.strokeColor=[UIColor whiteColor].CGColor;//边框颜色·
        self.shapeLayer.lineWidth = self.frame.size.width/8;
        
        CGMutablePathRef pathRef  = CGPathCreateMutable();
        
        CGPathAddArc(pathRef, &CGAffineTransformIdentity,
                     
                     CGRectGetWidth(self.progress.frame)/2, CGRectGetHeight(self.progress.frame)/2, self.frame.size.width/16, -M_PI/2, M_PI*3/2, NO);
        
        self.shapeLayer.path = pathRef;
    }
    
    if (![self.shapeLayer.superlayer isEqual:self.progress.layer]) {
        [self.progress.layer addSublayer:self.shapeLayer];
    }
    
    self.pathAniamtion = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    self.pathAniamtion.duration = 5;
    self.pathAniamtion.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    self.pathAniamtion.fromValue = fromValue;
    self.pathAniamtion.toValue = toValue;
    self.pathAniamtion.fillMode = kCAFillModeForwards;
    self.pathAniamtion.autoreverses = NO;
    [self.shapeLayer addAnimation:self.pathAniamtion forKey:nil];
}

- (float)lastRatio{
//    return objc_getAssociatedObject(self, @selector(lastRatio));
    NSNumber *is = objc_getAssociatedObject(self, @selector(lastRatio));
    if(is){
        return is.floatValue;
    }
    else{
        return NO;
    }
}

- (void)setLastRatio:(float)lastRatio{
    objc_setAssociatedObject(self, @selector(lastRatio), @(lastRatio), OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)isLoading{
    //    return objc_getAssociatedObject(self, @selector(lastRatio));
    NSNumber *is = objc_getAssociatedObject(self, @selector(isLoading));
    if(is){
        return is.floatValue;
    }
    else{
        return NO;
    }
}

- (void)setIsLoading:(BOOL)isLoading{
    objc_setAssociatedObject(self, @selector(isLoading), @(isLoading), OBJC_ASSOCIATION_RETAIN);
}

- (void)removeAll{
    [self.progress removeFromSuperview];
    self.progress = nil;
    [self.ratioProgress removeFromSuperview];
    self.ratioProgress = nil;
    [self.shapeLayer removeFromSuperlayer];
    self.shapeLayer = nil;
}

@end


@implementation UIImageView (WebCacheDeprecated)

- (NSURL *)imageURL {
    return [self sd_imageURL];
}

- (void)setImageWithURL:(NSURL *)url {
    [self sd_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:nil];
}

- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:nil];
}

- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:nil];
}

- (void)setImageWithURL:(NSURL *)url completed:(SDWebImageCompletedBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        if (completedBlock) {
            completedBlock(image, error, cacheType);
        }
    }];
}

- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder completed:(SDWebImageCompletedBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        if (completedBlock) {
            completedBlock(image, error, cacheType);
        }
    }];
}

- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options completed:(SDWebImageCompletedBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        if (completedBlock) {
            completedBlock(image, error, cacheType);
        }
    }];
}

- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options progress:(SDWebImageDownloaderProgressBlock)progressBlock completed:(SDWebImageCompletedBlock)completedBlock {
    [self sd_setImageWithURL:url placeholderImage:placeholder options:options progress:progressBlock completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        if (completedBlock) {
            completedBlock(image, error, cacheType);
        }
    }];
}

- (void)sd_setImageWithPreviousCachedImageWithURL:(NSURL *)url andPlaceholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options progress:(SDWebImageDownloaderProgressBlock)progressBlock completed:(SDWebImageCompletionBlock)completedBlock {
    [self sd_setImageWithPreviousCachedImageWithURL:url placeholderImage:placeholder options:options progress:progressBlock completed:completedBlock];
}

- (void)cancelCurrentArrayLoad {
    [self sd_cancelCurrentAnimationImagesLoad];
}

- (void)cancelCurrentImageLoad {
    [self sd_cancelCurrentImageLoad];
}

- (void)setAnimationImagesWithURLs:(NSArray *)arrayOfURLs {
    [self sd_setAnimationImagesWithURLs:arrayOfURLs];
}

@end
