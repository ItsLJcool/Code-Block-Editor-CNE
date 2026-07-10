import funkin.backend.systems.Flags;

import openfl.geom.ColorTransform;

import funkin.backend.utils.FlxInterpolateColor;

using StringTools;

final NOTE_NAME:String = "Rocket";

var tordStrumLine(get, never):StrumLine;
function get_tordStrumLine() return strumLines.members[2] ?? strumLines.members[0];

var tord(get, never):Character;
function get_tord() return tordStrumLine.characters[0];

// This is bad practice, as if there is a BPM change this would not follow the change.
// You'd want to have a function to convert beats/stepsToTime so you can reference the current time in steps instead of `Conductor.crochet`.
final CONDUCTOR_OFFSET:Float = Conductor.crochet * Conductor.beatsPerMeasure; // offsets by 1 measure.

final BEEP_SFX_LENGTHS:Array<Float> = [
    Conductor.crochet,
    Conductor.crochet*2, Conductor.crochet*2.5,
    Conductor.crochet * 3, Conductor.crochet * 3.5, Conductor.crochet * 4,
    -1
];

var target:FlxSprite = new FlxSprite().loadGraphic(Paths.image('stages/eddsworld/Target'));

final LAST_RANDOM_ROCET_POS:Int = -1;

function onNoteCreation(event:NoteCreationEvent) {
    if (event.noteType != NOTE_NAME) return;
    event.cancel();
    event.note.frames = Paths.getFrames('game/notes/$NOTE_NAME');
    event.note.animation.addByPrefix('scroll', 'Rocket!!!! instance 1', 24, true);
    event.note.animation.play('scroll', true);
    event.note.antialiasing = true;
    event.note.splash = "rocket";
    event.note.scrollSpeed = 5;
    event.note.scale.x = event.note.scale.y = event.note.strumLine.strumScale * Flags.DEFAULT_NOTE_SCALE;
    event.note.updateHitbox();

    event.note.strumTime += CONDUCTOR_OFFSET;
    LAST_RANDOM_ROCET_POS = event.note.noteData = FlxG.random.int(0, event.note.strumLine.members.length-1, [LAST_RANDOM_ROCET_POS]);
    event.note.extra.set("send_target", false);
}

function postCreate() {
    player.onNoteUpdate.add(rocket_update);
    
    target.colorTransform = new ColorTransform();
    insert(members.indexOf(strumLines)+1, target);
    target.antialiasing = true;
    target.scale.set(0.6, 0.6);
    target.updateHitbox();
    target.cameras = [camHUD];
    target.onDraw = target_draw;
}

function rocket_update(e:NoteUpdateEvent) {
    var note:Note = e.note;
    if (note.noteType != NOTE_NAME) return;
    
    var original_chart_time:Float = Conductor.songPosition - (note.strumTime - CONDUCTOR_OFFSET);
    if (!note.extra.get("send_target") && original_chart_time <= 0) {
        note.extra.set("send_target", true);
        target_appear(note, CONDUCTOR_OFFSET);
    }
}

//region Target Sprite Appear
var target_render_data:Array<Dynamic> = [];
final TARGET_INTRO_TIME:Float = 0.25; // in seconds
final COLOR_BEEP_TIME:Float = (Conductor.crochet*0.001)*4.5; // in seconds
function target_draw(spr:FlxSprite) {
    var prev_scale = FlxPoint.weak(spr.scale.x, spr.scale.y);
    var prev_alpha = spr.alpha;
    for (data in target_render_data) {
        spr.setPosition(data.strum.x + (data.strum.width - spr.width) * 0.5, data.strum.y + (data.strum.height - spr.height) * 0.5);
        if (data.intro_anim < TARGET_INTRO_TIME) {
            var lerp_scale:Float = FlxMath.lerp(prev_scale.x + 0.75, prev_scale.x, FlxEase.quadOut(data.intro_anim / TARGET_INTRO_TIME));
            var lerp_alpha:Float = FlxMath.lerp(1, 0, FlxEase.quadOut(data.intro_anim / TARGET_INTRO_TIME));

            spr.scale.set(lerp_scale, lerp_scale);
            spr.alpha = lerp_alpha;
            spr.colorTransform.color = FlxColor.WHITE;

            spr.draw();

            spr.scale.set(prev_scale.x, prev_scale.y);
            spr.alpha = prev_alpha;
            spr.colorTransform.color = FlxColor.RED;
        }
        if (data.color_beep_time < COLOR_BEEP_TIME) data.color_beep_interp.lerpTo(FlxColor.RED, data.color_beep_time / COLOR_BEEP_TIME);
        spr.colorTransform.color = data.color_beep_interp.color;
        spr.draw();
    }
    prev_scale.putWeak();
}

function target_appear(note:Note, offset:Float) {
    var strum:Strum = note.strumLine.members[note.noteData];
    var color_interpolate:FlxInterpolateColor = new FlxInterpolateColor();
    color_interpolate.lerpTo(FlxColor.RED, 1);
    target_render_data.push({
        strum: strum, time: note.strumTime,

        intro_anim: 0, remove_offset: offset, tord_anim: false,

        color_beep_time: COLOR_BEEP_TIME,
        color_beep_amt: 0,
        color_beep_interp: color_interpolate,
    });
}

function updateTargetAnim(elapsed:Float) {
    for (idx=>data in target_render_data) {
        var time_offset:Float = data.time - CONDUCTOR_OFFSET;
        if (Conductor.songPosition - (data.time - (Conductor.crochet*0.5)) > 0 && !data.tord_anim) {
            data.tord_anim = true;
            tord.playAnim("sendRocket", true, "LOCK");
            FORCE_ANIM = true;
            tord.animation.finishCallback = () -> {
                tord.animation.finishCallback = null;
                FORCE_ANIM = false;
            };
        }
        if (Conductor.songPosition - data.time > 0) target_render_data.splice(idx, 1);
        if (data.intro_anim < TARGET_INTRO_TIME) data.intro_anim += elapsed;

        if (BEEP_SFX_LENGTHS[data.color_beep_amt] >= 0) {
            var has_passed:Bool = (Conductor.songPosition > time_offset + BEEP_SFX_LENGTHS[data.color_beep_amt]);
            if (has_passed) {
                data.color_beep_time = 0;
                data.color_beep_amt++;
                data.color_beep_interp.lerpTo(FlxColor.WHITE, 1);
            }
            if (data.color_beep_time < COLOR_BEEP_TIME) data.color_beep_time += elapsed;
        } else data.color_beep_interp.lerpTo(FlxColor.RED, 1);
    }
}
//endregion

function update(elapsed:Float) {
    updateTargetAnim(elapsed);
}

var FORCE_ANIM:Bool = false;
function onNoteHit(event:NoteHitEvent) {
    if (event.noteType == NOTE_NAME) event.showSplash = true;
    if (!event.characters.contains(tord) || !FORCE_ANIM) return;
    event.preventAnim();
}

function onPlayerMiss(event:NoteHitEvent) {
    if (event.noteType != NOTE_NAME) return;
    event.cancel(); // doesn't play sfx or do anything cuz fuck you !!
    gameOver();
}