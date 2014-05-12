//
//  MainMenuScene.m
//  ZombieConga
//
//  Created by Ryoichi Hara on 2014/05/12.
//  Copyright (c) 2014年 Ryoichi Hara. All rights reserved.
//

#import "MainMenuScene.h"

@implementation MainMenuScene

- (instancetype)initWithSize:(CGSize)size {
    self = [super initWithSize:size];

    if (self) {
        SKSpriteNode *bg = [SKSpriteNode spriteNodeWithImageNamed:@"MainMenu"];
        bg.position = CGPointMake(self.size.width / 2, self.size.height / 2);
        [self addChild:bg];
    }

    return self;
}

@end
