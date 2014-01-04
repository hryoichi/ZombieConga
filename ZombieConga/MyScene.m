//
//  MyScene.m
//  ZombieConga
//
//  Created by Ryoichi Hara on 2013/12/01.
//  Copyright (c) 2013年 Ryoichi Hara. All rights reserved.
//

#import "MyScene.h"

@implementation MyScene
{
    SKSpriteNode *_zombie;
    CGPoint _velocity;
    NSTimeInterval _lastUpdateTime;
    NSTimeInterval _dt;
}

-(id)initWithSize:(CGSize)size
{
    if (self = [super initWithSize:size]) {
        self.backgroundColor = [SKColor whiteColor];
        SKSpriteNode *bg = [SKSpriteNode spriteNodeWithImageNamed:@"background"];
        bg.position = CGPointMake(self.size.width/2, self.size.height/2);
        [self addChild:bg];

        _zombie = [SKSpriteNode spriteNodeWithImageNamed:@"zombie1"];
        _zombie.position = CGPointMake(100.0, 100.0);
        // [_zombie setScale:2.0]; // SKNode method
        [self addChild:_zombie];
    }
    return self;
}

- (void)update:(NSTimeInterval)currentTime
{
    if (_lastUpdateTime) {
        _dt = currentTime - _lastUpdateTime;
    }
    else {
        _dt = 0;
    }
    _lastUpdateTime = currentTime;

    [self moveSprite:_zombie velocity:_velocity];
    [self rotateSprite:_zombie toFace:_velocity];
    [self boundsCheckPlayer];
}

#pragma mark - Touch Events

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInNode:self];
    [self moveZombieToward:touchLocation];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInNode:self];
    [self moveZombieToward:touchLocation];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInNode:self];
    [self moveZombieToward:touchLocation];
}

#pragma mark - Private

- (void)moveSprite:(SKSpriteNode *)sprite velocity:(CGPoint)velocity
{
    CGPoint amountToMove = CGPointMake(velocity.x * _dt, velocity.y * _dt);

    sprite.position = CGPointMake(sprite.position.x + amountToMove.x,
                                  sprite.position.y + amountToMove.y);
}

- (void)rotateSprite:(SKSpriteNode *)sprite toFace:(CGPoint)direction
{
    sprite.zRotation = atan2f(direction.y, direction.x);
}

- (void)moveZombieToward:(CGPoint)location
{
    CGPoint offset = CGPointMake(location.x - _zombie.position.x,
                                 location.y - _zombie.position.y);
    CGFloat length = sqrtf(offset.x * offset.x + offset.y * offset.y);

    // Normalizing a vector
    CGPoint direction = CGPointMake(offset.x / length, offset.y / length);

    _velocity = CGPointMake(direction.x * ZOMBIE_MOVE_POINTS_PER_SEC,
                            direction.y * ZOMBIE_MOVE_POINTS_PER_SEC);
}

- (void)boundsCheckPlayer
{
    CGPoint newPosition = _zombie.position;
    CGPoint newVelocity = _velocity;

    CGPoint bottomLeft = CGPointZero;
    CGPoint topRight = CGPointMake(self.size.width, self.size.height);

    if (newPosition.x <= bottomLeft.x) {
        newPosition.x = bottomLeft.x;
        newVelocity.x = -newVelocity.x;
    }
    if (newPosition.x >= topRight.x) {
        newPosition.x = topRight.x;
        newVelocity.x = -newVelocity.x;
    }

    if (newPosition.y <= bottomLeft.y) {
        newPosition.y = bottomLeft.y;
        newVelocity.y = -newVelocity.y;
    }
    if (newPosition.y >= topRight.y) {
        newPosition.y = topRight.y;
        newVelocity.y = -newVelocity.y;
    }

    _zombie.position = newPosition;
    _velocity = newVelocity;
}

@end
