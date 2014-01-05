//
//  MyScene.m
//  ZombieConga
//
//  Created by Ryoichi Hara on 2013/12/01.
//  Copyright (c) 2013年 Ryoichi Hara. All rights reserved.
//

#import "MyScene.h"

#define ARC4RANDOM_MAX 0x100000000

static inline CGFloat ScalarRandomRange(CGFloat min, CGFloat max)
{
    return floorf(((double)arc4random() / ARC4RANDOM_MAX) * (max - min) + min);
}

static inline CGPoint CGPointAdd(const CGPoint a, const CGPoint b)
{
    return CGPointMake(a.x + b.x, a.y + b.y);
}

static inline CGPoint CGPointSubtract(const CGPoint a, const CGPoint b)
{
    return CGPointMake(a.x - b.x, a.y - b.y);
}

static inline CGPoint CGPointMultiplyScalar(const CGPoint a, const CGFloat b)
{
    return CGPointMake(a.x * b, a.y * b);
}

static inline CGFloat CGPointLength(const CGPoint a)
{
    return sqrtf(a.x * a.x + a.y * a.y);
}

static inline CGPoint CGPointNormalize(const CGPoint a)
{
    CGFloat length = CGPointLength(a);
    return CGPointMake(a.x / length, a.y / length);
}

static inline CGFloat CGPointToAngle(const CGPoint a)
{
    return atan2f(a.y, a.x);
}

static inline CGFloat ScalarSign(CGFloat a)
{
    return a >= 0 ? 1 : -1;
}

// Returns shortest angle between two angles,
// between -M_PI and M_PI
static inline CGFloat ScalarShortestAngleBetween(const CGFloat a, const CGFloat b)
{
    CGFloat difference = b - a;
    CGFloat angle = fmodf(difference, M_PI * 2);
    if (angle >= M_PI) {
        angle -= M_PI * 2;
    }
    return angle;
}

@implementation MyScene
{
    SKSpriteNode *_zombie;
    CGPoint _velocity;
    NSTimeInterval _lastUpdateTime;
    NSTimeInterval _dt;
    CGPoint _lastTouchLocation;
    SKAction *_zombieAnimation;
}

#pragma mark - Lifecycle

-(id)initWithSize:(CGSize)size
{
    if (self = [super initWithSize:size]) {
        self.backgroundColor = [SKColor whiteColor];
        SKSpriteNode *bg = [SKSpriteNode spriteNodeWithImageNamed:@"background"];
        bg.position = CGPointMake(self.size.width/2, self.size.height/2);
        [self addChild:bg];

        _zombie = [SKSpriteNode spriteNodeWithImageNamed:@"zombie1"];
        _zombie.position = CGPointMake(100.0, 100.0);
        [self addChild:_zombie];

        NSMutableArray *textures = [NSMutableArray arrayWithCapacity:10];
        for (NSInteger i = 1; i < 4; i++) {
            NSString *textureName = [NSString stringWithFormat:@"zombie%d", i];
            SKTexture *texture = [SKTexture textureWithImageNamed:textureName];
            [textures addObject:texture];
        }

        for (NSInteger j = 4; j > 1; j--) {
            NSString *textureName = [NSString stringWithFormat:@"zombie%d", j];
            SKTexture *texture = [SKTexture textureWithImageNamed:textureName];
            [textures addObject:texture];
        }

        _zombieAnimation = [SKAction animateWithTextures:textures timePerFrame:0.1];
        // [_zombie runAction:[SKAction repeatActionForever:_zombieAnimation]];

        [self runAction:[SKAction repeatActionForever:[SKAction sequence:@[
            [SKAction performSelector:@selector(spawnEnemy) onTarget:self],
            [SKAction waitForDuration:2.0]
        ]]]];

        [self runAction:[SKAction repeatActionForever:[SKAction sequence:@[
            [SKAction performSelector:@selector(spawnCat) onTarget:self],
            [SKAction waitForDuration:1.0]
        ]]]];
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

    CGPoint offset = CGPointSubtract(_lastTouchLocation, _zombie.position);
    CGFloat distance = CGPointLength(offset);

    if (distance < ZOMBIE_MOVE_POINTS_PER_SEC * _dt) {
        _zombie.position = _lastTouchLocation;
        _velocity = CGPointZero;
        [self stopZombieAnimation];
    }
    else {
        [self moveSprite:_zombie velocity:_velocity];
        [self boundsCheckPlayer];
        [self rotateSprite:_zombie toFace:_velocity rotateRadiansPerSec:ZOMBIE_ROTATE_RADIANS_PER_SEC];
    }
}

#pragma mark - Touch Events

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInNode:self];
    [self moveZombieToward:touchLocation];

    _lastTouchLocation = touchLocation;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInNode:self];
    [self moveZombieToward:touchLocation];

    _lastTouchLocation = touchLocation;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInNode:self];
    [self moveZombieToward:touchLocation];

    _lastTouchLocation = touchLocation;
}

#pragma mark - Private

- (void)moveSprite:(SKSpriteNode *)sprite velocity:(CGPoint)velocity
{
    CGPoint amountToMove = CGPointMultiplyScalar(velocity, _dt);
    sprite.position = CGPointAdd(sprite.position, amountToMove);
}

- (void)rotateSprite:(SKSpriteNode *)sprite toFace:(CGPoint)velocity
{
    sprite.zRotation = CGPointToAngle(velocity);
}

- (void)rotateSprite:(SKSpriteNode *)sprite
              toFace:(CGPoint)velocity
 rotateRadiansPerSec:(CGFloat)rotateRadiansPerSec
{
    CGFloat targetAngle = CGPointToAngle(velocity);
    CGFloat shortest = ScalarShortestAngleBetween(sprite.zRotation, targetAngle);

    CGFloat amtToRotate = rotateRadiansPerSec * _dt;
    if (ABS(shortest) < amtToRotate) {
        amtToRotate = ABS(shortest);
    }

    sprite.zRotation += ScalarSign(shortest) * amtToRotate;
}

- (void)moveZombieToward:(CGPoint)location
{
    [self startZombieAnimation];

    CGPoint offset = CGPointSubtract(location, _zombie.position);
    CGPoint direction = CGPointNormalize(offset);

    _velocity = CGPointMultiplyScalar(direction, ZOMBIE_MOVE_POINTS_PER_SEC);
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

- (void)spawnEnemy
{
    SKSpriteNode *enemy = [SKSpriteNode spriteNodeWithImageNamed:@"enemy"];
    enemy.position = CGPointMake(self.size.width + enemy.size.width/2,
                                 ScalarRandomRange(enemy.size.height/2, self.size.height - enemy.size.height/2));
    [self addChild:enemy];

    SKAction *actionMove = [SKAction moveToX:-enemy.size.width/2 duration:2.0];
    SKAction *actionRemove = [SKAction removeFromParent];

    [enemy runAction:[SKAction sequence:@[actionMove, actionRemove]]];
}

- (void)spawnCat
{
    SKSpriteNode *cat = [SKSpriteNode spriteNodeWithImageNamed:@"cat"];
    cat.position = CGPointMake(
        ScalarRandomRange(0, self.size.width),
        ScalarRandomRange(0, self.size.height)
    );
    [cat setScale:0];
    cat.zRotation = -M_PI / 16;
    [self addChild:cat];

    SKAction *appear = [SKAction scaleTo:1.0 duration:0.5];

    SKAction *leftWiggle = [SKAction rotateByAngle:M_PI/8 duration:0.5];
    SKAction *rightWiggle = [leftWiggle reversedAction];
    SKAction *fullWiggle = [SKAction sequence:@[leftWiggle, rightWiggle]];
    SKAction *wiggleWait = [SKAction repeatAction:fullWiggle count:10];

    SKAction *disappear = [SKAction scaleTo:0.0 duration:0.5];
    SKAction *removeFromParent = [SKAction removeFromParent];

    [cat runAction:[SKAction sequence:@[appear, wiggleWait, disappear, removeFromParent]]];
}

- (void)startZombieAnimation
{
    if (![_zombie actionForKey:@"animation"]) {
        [_zombie runAction:[SKAction repeatActionForever:_zombieAnimation] withKey:@"animation"];
    }
}

- (void)stopZombieAnimation
{
    [_zombie removeActionForKey:@"animation"];
}

@end
