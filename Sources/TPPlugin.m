#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "TPPluginBootstrap.h"
#import "TPRuntimeGuard.h"
#import "TPTranslationRenderer.h"
static void(*TPOriginalViewDidAppear)(id,SEL,BOOL);
static void(*TPOriginalTableLayoutSubviews)(id,SEL);
static void TPViewDidAppear(UIViewController*self,SEL cmd,BOOL animated){TPOriginalViewDidAppear(self,cmd,animated);dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.25*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[TPPluginBootstrap.shared controllerDidAppear:self];});}
static void TPTableLayoutSubviews(UITableView*self,SEL cmd){TPOriginalTableLayoutSubviews(self,cmd);[TPTranslationRenderer adjustVisibleSpacingInTableView:self];}
__attribute__((constructor))static void TPInitialize(void){@autoreleasepool{if(!TPRuntimeGuard.canStart)return;Method m=class_getInstanceMethod(UIViewController.class,@selector(viewDidAppear:));TPOriginalViewDidAppear=(void*)method_getImplementation(m);method_setImplementation(m,(IMP)TPViewDidAppear);Method t=class_getInstanceMethod(UITableView.class,@selector(layoutSubviews));TPOriginalTableLayoutSubviews=(void*)method_getImplementation(t);method_setImplementation(t,(IMP)TPTableLayoutSubviews);[TPPluginBootstrap.shared start];}}
