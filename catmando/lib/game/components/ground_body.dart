import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../game_config.dart';

class GroundBody extends BodyComponent {
  GroundBody({required double centerX})
      : super(
          renderBody: false,
          bodyDef: BodyDef(
            position: Vector2(centerX, GameConfig.groundY),
            type: BodyType.static,
          ),
          fixtureDefs: [
            FixtureDef(
              PolygonShape()
                ..setAsBox(
                  GameConfig.groundWidth / 2,
                  GameConfig.groundHalfH,
                  Vector2.zero(),
                  0,
                ),
              friction: 0.95,
            ),
          ],
        );
}
