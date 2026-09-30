import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../cat_sprites.dart';
import '../game_config.dart';

class StackedCatBody extends BodyComponent {
  StackedCatBody({
    required this.spriteIndex,
    required Vector2 position,
    required double angle,
    Vector2? linearVelocity,
  })  : catInfo = CatSprites.infoForIndex(spriteIndex),
        super(
          renderBody: false,
          bodyDef: BodyDef(
            position: position,
            angle: angle,
            type: BodyType.dynamic,
            linearVelocity: linearVelocity,
            linearDamping: GameConfig.fallingLinearDamping,
            angularDamping: GameConfig.fallingAngularDamping,
          ),
        );

  final int spriteIndex;
  final CatSpriteInfo catInfo;
  bool settled = false;
  bool isPhysicsStatic = false;
  Joint? _supportJoint;

  bool get isLockedToStack => _supportJoint != null;

  void markSettled() => freeze();

  /// Üst kat — ip beklerken hafif dynamic + weld.
  void freeze() {
    settled = true;
    isPhysicsStatic = false;
    body.setType(BodyType.dynamic);
    body.linearVelocity.setZero();
    body.angularVelocity = 0;
    body.linearDamping = GameConfig.settledLinearDamping;
    body.angularDamping = GameConfig.settledAngularDamping;
  }

  /// Alt kat — static + weld; uzun kulede devrilmeyi önler.
  void freezeAsStatic() {
    settled = true;
    isPhysicsStatic = true;
    destroySupportJoint();
    body.setType(BodyType.static);
    body.linearVelocity.setZero();
    body.angularVelocity = 0;
  }

  void promoteToDynamic() {
    if (!isPhysicsStatic) return;
    isPhysicsStatic = false;
    body.setType(BodyType.dynamic);
    body.linearVelocity.setZero();
    body.angularVelocity = 0;
    body.linearDamping = GameConfig.settledLinearDamping;
    body.angularDamping = GameConfig.settledAngularDamping;
  }

  /// Alttaki gövdeye sabit weld (dünya koordinatında anchor).
  void weldTo(Body supportBody, Vector2 worldAnchor) {
    destroySupportJoint();
    final def = WeldJointDef();
    def.initialize(supportBody, body, worldAnchor);
    def.collideConnected = false;
    def.frequencyHz = 0;
    def.dampingRatio = 0;
    _supportJoint = WeldJoint(def);
    body.world.createJoint(_supportJoint!);
  }

  void destroySupportJoint() {
    final joint = _supportJoint;
    if (joint != null) {
      Joint.destroy(joint);
      _supportJoint = null;
    }
  }

  void dampForGameOver() {
    destroySupportJoint();
    body.linearVelocity.setZero();
    body.angularVelocity = 0;
    body.linearDamping = GameConfig.gameOverLinearDamping;
    body.angularDamping = GameConfig.gameOverAngularDamping;
  }

  /// Yeni kedi düşerken weld kırılır, kule tekrar fizikle sallanır.
  void wakeForDrop() {
    if (!settled) return;
    isPhysicsStatic = false;
    destroySupportJoint();
    body.setType(BodyType.dynamic);
    body.linearDamping = GameConfig.wakingLinearDamping;
    body.angularDamping = GameConfig.wakingAngularDamping;
  }

  @override
  void onRemove() {
    destroySupportJoint();
    super.onRemove();
  }

  @override
  Body createBody() {
    final body = world.createBody(bodyDef!);
    body.createFixture(
      FixtureDef(
        PolygonShape()
          ..setAsBox(
            // Görselden biraz daha geniş — PNG şeffaf kenar yüzünden kaymasın.
            catInfo.contentHalfW * 1.12,
            catInfo.contentHalfH * 0.94,
            catInfo.contentCenterOffsetWorld,
            0,
          ),
        density: 1.0,
        friction: 1.35,
        restitution: 0,
      ),
    );
    return body;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      SpriteComponent(
        sprite: catInfo.displaySprite,
        size: catInfo.contentWorldSize,
        anchor: Anchor.center,
        position: catInfo.contentCenterOffsetWorld,
      ),
    );
  }
}
