//
//  MainMenuScene.m
//  ZombieConga
//
//  Created by Ryoichi Hara on 2014/05/12.
//  Copyright (c) 2014年 Ryoichi Hara. All rights reserved.
//

#import "MainMenuScene.h"
#import "MyScene.h"

@interface MainMenuScene ()

@property (nonatomic, strong) MyScene *myScene;

@end

@implementation MainMenuScene

- (instancetype)initWithSize:(CGSize)size {
    self = [super initWithSize:size];

    if (self) {
        SKSpriteNode *bg = [SKSpriteNode spriteNodeWithImageNamed:@"MainMenu"];
        bg.position = CGPointMake(self.size.width / 2, self.size.height / 2);
        [self addChild:bg];

        // NOTE: Load in advance because loading myScene is heavy
        _myScene = [[MyScene alloc] initWithSize:self.size];
    }

    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    SKTransition *reveal = [SKTransition doorwayWithDuration:0.5];
    [self.view presentScene:self.myScene transition:reveal];
}

@end
