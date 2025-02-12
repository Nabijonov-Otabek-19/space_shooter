import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/collisions.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

class SpaceShooterGame extends FlameGame
    with HasCollisionDetection, PanDetector {
  late Rocket rocket;
  final Random random = Random();
  bool isGameOver = false;
  int score = 0;
  late TextComponent scoreText;

  final space1 = "space1.jpg";
  final space2 = "space2.png";
  final space3 = "space3.jpeg";

  void increaseScore() {
    score++;
    scoreText.text = 'Score: $score';
  }

  void spawnRocks() {
    add(
      TimerComponent(
        period: 1.2,
        repeat: true,
        onTick: () {
          if (!isGameOver) {
            final rock = SpaceRock(Vector2(random.nextDouble() * size.x, -50));
            add(rock);
          }
        },
      ),
    );
  }

  void gameOver() {
    if (isGameOver) return;
    isGameOver = true;
    overlays.add('GameOver');
    pauseEngine();
  }

  void restartGame() {
    overlays.remove('GameOver');
    isGameOver = false;

    children.whereType<SpaceRock>().forEach((rock) => rock.removeFromParent());
    children.whereType<Bullet>().forEach((bullet) => bullet.removeFromParent());
    if (rocket.shootTimer != null) {
      rocket.shootTimer!.removeFromParent();
      rocket.shootTimer = null;
    }
    rocket.removeFromParent();

    score = 0;
    scoreText.text = 'Score: 0';

    Future.microtask(() {
      resetGame();
      resumeEngine();
    });
  }

  void resetGame() {
    rocket = Rocket();
    add(rocket);
    spawnRocks();
  }

  @override
  Future<void> onLoad() async {
    overlays.addEntry(
        'GameOver', (context, game) => buildGameOverOverlay(context));

    // Add score display
    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(size.x / 2, 30),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    final bgSprite = await loadSprite(space3);

    // Calculate aspect ratio
    final imageAspectRatio = bgSprite.image.width / bgSprite.image.height;
    final screenAspectRatio = size.x / size.y;

    Vector2 bgSize;
    if (imageAspectRatio > screenAspectRatio) {
      // Image is wider than screen: Fit height and adjust width
      bgSize = Vector2(size.y * imageAspectRatio, size.y);
    } else {
      // Image is taller than screen: Fit width and adjust height
      bgSize = Vector2(size.x, size.x / imageAspectRatio);
    }

    final bgImage = SpriteComponent(
      sprite: bgSprite,
      size: bgSize,
      position: Vector2((size.x - bgSize.x) / 2, (size.y - bgSize.y) / 2),
    );

    add(bgImage);
    add(scoreText);

    resetGame();
  }

  @override
  void onPanStart(DragStartInfo info) {
    if (rocket.containsPoint(info.eventPosition.widget)) {
      rocket.isBeingDragged = true;
      rocket.startShooting();
    }
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (rocket.isBeingDragged) {
      // Use the absolute position of the finger instead of delta
      final halfWidth = rocket.width / 2;
      final halfHeight = rocket.height / 2;

      final newX =
          info.eventPosition.widget.x.clamp(halfWidth, size.x - halfWidth);
      final newY =
          info.eventPosition.widget.y.clamp(halfHeight, size.y - halfHeight);

      rocket.position = Vector2(newX, newY);
    }
  }

  @override
  void onPanEnd(DragEndInfo info) {
    rocket.isBeingDragged = false;
    rocket.stopShooting();
  }

  Widget buildGameOverOverlay(BuildContext context) {
    return Center(
      child: AlertDialog(
        title: const Text("Game Over"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("You crashed into a rock!"),
            const SizedBox(height: 10),
            Text(
              "Final Score: $score",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: restartGame,
            child: const Text("Restart"),
          ),
        ],
      ),
    );
  }
}

// Rest of the classes remain the same
class Rocket extends SpriteComponent
    with HasGameRef<SpaceShooterGame>, CollisionCallbacks {
  bool isBeingDragged = false;
  TimerComponent? shootTimer;

  // Adjust the rocket size if necessary
  static final Vector2 rocketSize = Vector2(50, 75);

  Rocket() : super(size: rocketSize);

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('rocket.png');
    position = Vector2(gameRef.size.x / 2, gameRef.size.y - 100);
    anchor = Anchor.center;

    add(RectangleHitbox());
  }

  void startShooting() {
    if (shootTimer == null) {
      shootTimer = TimerComponent(
        period: 0.3,
        repeat: true,
        onTick: () {
          gameRef.add(Bullet(Vector2(position.x, position.y - 30)));
          //FlameAudio.play('shoot.wav');
        },
      );
      gameRef.add(shootTimer!);
    }
  }

  void stopShooting() {
    shootTimer?.removeFromParent();
    shootTimer = null;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is SpaceRock && !gameRef.isGameOver) {
      gameRef.gameOver();
    }
  }
}

class Bullet extends SpriteComponent
    with HasGameRef<SpaceShooterGame>, CollisionCallbacks {
  static const double bulletSpeed = 400.0;

  Bullet(Vector2 position)
      : super(
          size: Vector2(10, 20),
          position: position,
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('bullet.png');
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    position.y -= bulletSpeed * dt;
    if (position.y < 0) {
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is SpaceRock) {
      gameRef.increaseScore();
      other.removeFromParent();
      removeFromParent();

      // Play explosion sound when bullet hits rock
      FlameAudio.play('explosion.wav');
    }
  }
}

class SpaceRock extends SpriteComponent
    with HasGameRef<SpaceShooterGame>, CollisionCallbacks {
  static const double rockSpeed = 100.0;

  SpaceRock(Vector2 position)
      : super(
          size: Vector2(50, 50),
          position: position,
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    sprite = await gameRef.loadSprite('rock.png');
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    position.y += rockSpeed * dt;
    if (position.y > gameRef.size.y) {
      removeFromParent();
    }
  }
}
