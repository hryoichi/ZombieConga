//
//  MyScene.m
//  ZombieConga
//
//  Created by Ryoichi Hara on 2013/12/01.
//  Copyright (c) 2013年 Ryoichi Hara. All rights reserved.
//

#import "MyScene.h"
@import AVFoundation;
#import "GameOverScene.h"

static const CGFloat ZOMBIE_MOVE_POINTS_PER_SEC = 120.0f;
static const CGFloat ZOMBIE_ROTATE_RADIANS_PER_SEC = 4 * M_PI;
static const CGFloat CAT_MOVE_POINTS_PER_SEC = 120.0f;
static const CGFloat BG_POINTS_PER_SEC = 50.0f;

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
    SKAction *_catCollisionSound;
    SKAction *_enemyCollisionSound;
    BOOL _invincible;
    NSInteger _lives;
    BOOL _gameOver;
    AVAudioPlayer *_backgroundMusicPlayer;
    SKNode *_bgLayer;
}

#pragma mark - Lifecycle

-(id)initWithSize:(CGSize)size
{
    if (self = [super initWithSize:size]) {
        _bgLayer = [SKNode node];
        [self addChild:_bgLayer];

        self.backgroundColor = [SKColor whiteColor];
        _lives = 5;
        _gameOver = NO;
        [self playBackgroundMusic:@"bgMusic.mp3"];

        for (NSInteger i = 0; i < 2; i++) {
            SKSpriteNode *bg = [SKSpriteNode spriteNodeWithImageNamed:@"background"];
            bg.anchorPoint = CGPointZero;
            bg.position = CGPointMake(i * bg.size.width, 0.0f);
            bg.name = @"bg";
            [_bgLayer addChild:bg];
        }

        _zombie = [SKSpriteNode spriteNodeWithImageNamed:@"zombie1"];
        _zombie.position = CGPointMake(100.0f, 100.0f);
        _zombie.zPosition = 100.0f;
        [_bgLayer addChild:_zombie];

        NSMutableArray *textures = [NSMutableArray arrayWithCapacity:10];
        for (NSInteger i = 1; i < 4; i++) {
            NSString *textureName = [NSString stringWithFormat:@"zombie%ld", (long)i];
            SKTexture *texture = [SKTexture textureWithImageNamed:textureName];
            [textures addObject:texture];
        }

        for (NSInteger j = 4; j > 1; j--) {
            NSString *textureName = [NSString stringWithFormat:@"zombie%ld", (long)j];
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

        _catCollisionSound = [SKAction playSoundFileNamed:@"hitCat.wav" waitForCompletion:NO];
        _enemyCollisionSound = [SKAction playSoundFileNamed:@"hitCatLady.wav" waitForCompletion:NO];
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
    [self boundsCheckPlayer];
    [self rotateSprite:_zombie toFace:_velocity rotateRadiansPerSec:ZOMBIE_ROTATE_RADIANS_PER_SEC];

    [self moveTrain];
    [self moveBg];

    if (_lives <= 0 && !_gameOver) {
        _gameOver = YES;
        NSLog(@"Your lose!");

        [_backgroundMusicPlayer stop];

        SKScene *gameOverScene = [[GameOverScene alloc] initWithSize:self.size won:NO];
        SKTransition *reveal = [SKTransition flipHorizontalWithDuration:0.5];
        [self.view presentScene:gameOverScene transition:reveal];
    }
}

- (void)didEvaluateActions {
    [self checkCollisions];
}

#pragma mark - Touch Events

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInNode:_bgLayer];
    [self moveZombieToward:touchLocation];

    _lastTouchLocation = touchLocation;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInNode:_bgLayer];
    [self moveZombieToward:touchLocation];

    _lastTouchLocation = touchLocation;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInNode:_bgLayer];
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

- (void)boundsCheckPlayer {
    CGPoint newPosition = _zombie.position;
    CGPoint newVelocity = _velocity;

    CGPoint bottomLeft = [_bgLayer convertPoint:CGPointZero fromNode:self];
    CGPoint topRight = [_bgLayer convertPoint:CGPointMake(self.size.width, self.size.height) fromNode:self];

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

- (void)spawnEnemy {
    SKSpriteNode *enemy = [SKSpriteNode spriteNodeWithImageNamed:@"enemy"];
    enemy.name = @"enemy";
    CGPoint enemyScenePos = CGPointMake(
        self.size.width + enemy.size.width / 2,
        ScalarRandomRange(enemy.size.height / 2, self.size.height - enemy.size.height / 2)
    );
    enemy.position = [self convertPoint:enemyScenePos toNode:_bgLayer];
    [_bgLayer addChild:enemy];

    SKAction *actionMove = [SKAction moveByX:-self.size.width + enemy.size.width y:0 duration:2.0];
    SKAction *actionRemove = [SKAction removeFromParent];

    [enemy runAction:[SKAction sequence:@[actionMove, actionRemove]]];
}

- (void)spawnCat
{
    SKSpriteNode *cat = [SKSpriteNode spriteNodeWithImageNamed:@"cat"];
    cat.name = @"cat";
    CGPoint catScenePos = CGPointMake(
        ScalarRandomRange(0, self.size.width),
        ScalarRandomRange(0, self.size.height)
    );
    cat.position = [self convertPoint:catScenePos toNode:_bgLayer];
    [cat setScale:0];
    cat.zRotation = -M_PI / 16;
    [_bgLayer addChild:cat];

    SKAction *appear = [SKAction scaleTo:1.0 duration:0.5];

    SKAction *leftWiggle = [SKAction rotateByAngle:M_PI/8 duration:0.5];
    SKAction *rightWiggle = [leftWiggle reversedAction];
    SKAction *fullWiggle = [SKAction sequence:@[leftWiggle, rightWiggle]];

    SKAction *scaleUp = [SKAction scaleBy:1.2 duration:0.25];
    SKAction *scaleDown = [scaleUp reversedAction];
    SKAction *fullScale = [SKAction sequence:@[scaleUp, scaleDown, scaleUp, scaleDown]];

    SKAction *group = [SKAction group:@[fullScale, fullWiggle]];
    SKAction *groupWait = [SKAction repeatAction:group count:10];

    SKAction *disappear = [SKAction scaleTo:0.0 duration:0.5];
    SKAction *removeFromParent = [SKAction removeFromParent];

    [cat runAction:[SKAction sequence:@[appear, groupWait, disappear, removeFromParent]]];
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

- (void)checkCollisions
{
    [_bgLayer enumerateChildNodesWithName:@"cat" usingBlock:^(SKNode *node, BOOL *stop) {
        SKSpriteNode *cat = (SKSpriteNode *)node;
        if (CGRectIntersectsRect(cat.frame, _zombie.frame)) {
            // [cat removeFromParent];
            [self runAction:_catCollisionSound];
            cat.name = @"train";
            [cat removeAllActions];
            [cat setScale:1.0f];
            cat.zRotation = 0.0f;
            [cat runAction:[SKAction colorizeWithColor:[SKColor greenColor] colorBlendFactor:1.0f duration:0.2]];
        }
    }];

    if (_invincible) return;

    [_bgLayer enumerateChildNodesWithName:@"enemy" usingBlock:^(SKNode *node, BOOL *stop) {
        SKSpriteNode *enemy = (SKSpriteNode *)node;
        CGRect smallerFrame = CGRectInset(enemy.frame, 20.0, 20.0);

        if (CGRectIntersectsRect(smallerFrame, _zombie.frame)) {
            // [enemy removeFromParent];
            [self runAction:_enemyCollisionSound];
            [self loseCats];
            _lives--;

            _invincible = YES;

            CGFloat blinkTimes = 10.0f;
            NSTimeInterval blinkDuration = 3.0;
            SKAction *blinkAction = [SKAction customActionWithDuration:blinkDuration actionBlock:^(SKNode *node, CGFloat elapsedTime) {
                CGFloat durationPerTime = blinkDuration / blinkTimes;
                CGFloat remainder = fmodf(elapsedTime, durationPerTime);
                node.hidden = remainder > (durationPerTime / 2);
            }];

            SKAction *sequence = [SKAction sequence:@[blinkAction, [SKAction runBlock:^{
                _zombie.hidden = NO;
                _invincible = NO;
            }]]];
            [_zombie runAction:sequence];
        }
    }];
}

- (void)moveTrain {
    __block NSInteger trainCount = 0;
    __block CGPoint targetPosition = _zombie.position;
    [_bgLayer enumerateChildNodesWithName:@"train" usingBlock:^(SKNode *node, BOOL *stop) {
        trainCount++;
        if (!node.hasActions) {
            CGFloat actionDuration = 0.3f;
            CGPoint offset = CGPointSubtract(targetPosition, node.position);
            CGPoint direction = CGPointNormalize(offset);
            CGPoint amountToMovePerSec = CGPointMultiplyScalar(direction, CAT_MOVE_POINTS_PER_SEC);
            CGPoint amountToMove = CGPointMultiplyScalar(amountToMovePerSec, actionDuration);
            SKAction *moveAction = [SKAction moveByX:amountToMove.x y:amountToMove.y duration:actionDuration];
            [node runAction:moveAction];
        }
        targetPosition = node.position;
    }];

    if (trainCount >= 30 && !_gameOver) {
        _gameOver = YES;
        NSLog(@"You win!");

        [_backgroundMusicPlayer stop];

        SKScene *gameOverScene = [[GameOverScene alloc] initWithSize:self.size won:YES];
        SKTransition *reveal = [SKTransition flipHorizontalWithDuration:0.5];
        [self.view presentScene:gameOverScene transition:reveal];
    }
}

- (void)loseCats {
    __block NSInteger loseCount = 0;
    [_bgLayer enumerateChildNodesWithName:@"train" usingBlock:^(SKNode *node, BOOL *stop) {
        CGPoint randomSpot = node.position;
        randomSpot.x += ScalarRandomRange(-100.0f, 100.0f);
        randomSpot.y += ScalarRandomRange(-100.0f, 100.0f);

        node.name = @"";

        SKAction *group = [SKAction group:@[
            [SKAction rotateByAngle:M_PI * 4 duration:1.0],
            [SKAction moveTo:randomSpot duration:1.0],
            [SKAction scaleTo:0.0f duration:1.0]
        ]];
        SKAction *sequence = [SKAction sequence:@[group, [SKAction removeFromParent]]];
        [node runAction:sequence];

        loseCount++;
        if (loseCount >= 2) {
            *stop = YES;
        }
    }];
}

- (void)moveBg {
    CGPoint bgVelocity = CGPointMake(-BG_POINTS_PER_SEC, 0);
    CGPoint amountToMove = CGPointMultiplyScalar(bgVelocity, _dt);
    _bgLayer.position = CGPointAdd(_bgLayer.position, amountToMove);

    [_bgLayer enumerateChildNodesWithName:@"bg" usingBlock:^(SKNode *node, BOOL *stop) {
        SKSpriteNode *bg = (SKSpriteNode *)node;
        CGPoint bgScreenPos = [_bgLayer convertPoint:bg.position toNode:self];

        if (bgScreenPos.x <= -bg.size.width) {
            bg.position = CGPointMake(bg.position.x + bg.size.width * 2, bg.position.y);
        }
    }];
}

#pragma mark - Audio helper

- (void)playBackgroundMusic:(NSString *)filename {
    NSError *error;
    NSURL *backgroundMusicURL = [[NSBundle mainBundle] URLForResource:filename withExtension:nil];

    _backgroundMusicPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:backgroundMusicURL error:&error];
    _backgroundMusicPlayer.numberOfLoops = -1;
    [_backgroundMusicPlayer prepareToPlay];
    [_backgroundMusicPlayer play];
}

@end
