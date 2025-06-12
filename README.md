# flixel-animate

Flixel-animate is a [HaxeFlixel](https://haxeflixel.com/) library meant to load texture atlases generated both from Adobe Animate and the [BetterTextureAtlas plugin](https://github.com/Dot-Stuff/BetterTextureAtlas).
The library is heavily inspired by [FlxAnimate](https://github.com/Dot-Stuff/flxanimate), though with some differences to work similarly to the Flash/Animate JSFL implementation.

## How to use

To create a sprite with a loaded texture atlas, create an ``FlxAnimate`` sprite object.
The class ``FlxAnimate`` is meant as a replacement to ``FlxSprite``, its capable of loading both
normal atlases (such as Sparrow) and Adobe Animate texture atlases.

Heres a small sample:

```haxe
import animate.FlxAnimate;
import animate.FlxAnimateFrames;

var sprite:FlxAnimate = new FlxAnimate();
sprite.frames = FlxAnimateFrames.fromAnimate('path/to/atlas');
add(sprite);

sprite.anim.addByTimeline("main animation", sprite.library.timeline);
sprite.anim.play("main animation");
```

Note that the ``sprite.anim`` variable is meant to access animation setting functions such as ``addByTimeline`` and is NOT a replacement to ``sprite.animation``.
This means you're still capable of using ``sprite.animation.play`` and it'll play any kind of animation, both from flixel and this library.

## Ways to add animations

Here's a list of all the ways to add animations when using an Adobe Animate texture atlas.

```haxe
sprite.anim.addBySymbol("symbolAnim", "symbolName");
sprite.anim.addBySymbolIndices("symbolAnim", "symbolName", [0, 1, 2, 3]);

sprite.anim.addByTimeline("tlAnim", someTimelineObject);
sprite.anim.addByTimelineIndices("tlIndicesAnim", someTimelineObject, [0, 1, 2, 3]);

sprite.anim.addByLabel("labelAnim", "frameLabelName");
sprite.anim.addByLabelIndices("labelIndicesAnim", "frameLabelName", [0, 1, 2, 3])
```
