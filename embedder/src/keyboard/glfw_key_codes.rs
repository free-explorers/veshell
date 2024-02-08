#![allow(non_upper_case_globals)]
#![allow(dead_code)]

use std::collections::HashMap;

use input_linux::sys::*;
use lazy_static::lazy_static;
use smithay::input::keyboard::ModifiersState;

pub fn get_glfw_keycode(xkb_keycode: u32) -> u32 {
    keycode_to_glfwkey_map
        .get(&xkb_keycode)
        .copied()
        .unwrap_or(xkb_keycode)
}

pub fn get_glfw_modifiers(mods_state: ModifiersState) -> u32 {
    let mut mods = 0;

    if mods_state.shift {
        mods |= kGlfwModifierShift;
    }
    if mods_state.ctrl {
        mods |= kGlfwModifierControl;
    }
    if mods_state.alt {
        mods |= kGlfwModifierAlt;
    }
    if mods_state.logo {
        mods |= kGlfwModifierSuper;
    }
    if mods_state.caps_lock {
        mods |= kGlfwModifierCapsLock;
    }
    if mods_state.num_lock {
        mods |= kGlfwModifierNumLock;
    }

    mods
}

const kGlfwModifierShift: u32 = 0x0001;
const kGlfwModifierControl: u32 = 0x0002;
const kGlfwModifierAlt: u32 = 0x0004;
const kGlfwModifierSuper: u32 = 0x0008;
const kGlfwModifierCapsLock: u32 = 0x0010;
const kGlfwModifierNumLock: u32 = 0x0020;

// Printable keys
const kGlfwKeySpace: u32 = 32;
const kGlfwKeyApostrophe: u32 = 39; /* ' */
const kGlfwKeyComma: u32 = 44; /* , */
const kGlfwKeyMinus: u32 = 45; /* - */
const kGlfwKeyPeriod: u32 = 46; /* . */
const kGlfwKeySlash: u32 = 47; /* / */
const kGlfwKey0: u32 = 48;
const kGlfwKey1: u32 = 49;
const kGlfwKey2: u32 = 50;
const kGlfwKey3: u32 = 51;
const kGlfwKey4: u32 = 52;
const kGlfwKey5: u32 = 53;
const kGlfwKey6: u32 = 54;
const kGlfwKey7: u32 = 55;
const kGlfwKey8: u32 = 56;
const kGlfwKey9: u32 = 57;
const kGlfwKeySemicolon: u32 = 59; /* ; */
const kGlfwKeyEqual: u32 = 61; /* = */
const kGlfwKeyA: u32 = 65;
const kGlfwKeyB: u32 = 66;
const kGlfwKeyC: u32 = 67;
const kGlfwKeyD: u32 = 68;
const kGlfwKeyE: u32 = 69;
const kGlfwKeyF: u32 = 70;
const kGlfwKeyG: u32 = 71;
const kGlfwKeyH: u32 = 72;
const kGlfwKeyI: u32 = 73;
const kGlfwKeyJ: u32 = 74;
const kGlfwKeyK: u32 = 75;
const kGlfwKeyL: u32 = 76;
const kGlfwKeyM: u32 = 77;
const kGlfwKeyN: u32 = 78;
const kGlfwKeyO: u32 = 79;
const kGlfwKeyP: u32 = 80;
const kGlfwKeyQ: u32 = 81;
const kGlfwKeyR: u32 = 82;
const kGlfwKeyS: u32 = 83;
const kGlfwKeyT: u32 = 84;
const kGlfwKeyU: u32 = 85;
const kGlfwKeyV: u32 = 86;
const kGlfwKeyW: u32 = 87;
const kGlfwKeyX: u32 = 88;
const kGlfwKeyY: u32 = 89;
const kGlfwKeyZ: u32 = 90;
const kGlfwKeyLeftBracket: u32 = 91; /* [ */
const kGlfwKeyBackslash: u32 = 92; /* \ */
const kGlfwKeyRightBracket: u32 = 93; /* ] */
const kGlfwKeyGraveAccent: u32 = 96; /* ` */
// const kGlfwKeyWorld1: u32 = 161;      /* non-US #1 */
// const kGlfwKeyWorld2: u32 = 162;      /* non-US #2 */
// Function keys
const kGlfwKeyEscape: u32 = 256;
const kGlfwKeyEnter: u32 = 257;
const kGlfwKeyTab: u32 = 258;
const kGlfwKeyBackspace: u32 = 259;
const kGlfwKeyInsert: u32 = 260;
const kGlfwKeyDelete: u32 = 261;
const kGlfwKeyRight: u32 = 262;
const kGlfwKeyLeft: u32 = 263;
const kGlfwKeyDown: u32 = 264;
const kGlfwKeyUp: u32 = 265;
const kGlfwKeyPageUp: u32 = 266;
const kGlfwKeypageDown: u32 = 267;
const kGlfwKeyHome: u32 = 268;
const kGlfwKeyEnd: u32 = 269;
const kGlfwKeyCapsLock: u32 = 280;
const kGlfwKeyScrollLock: u32 = 281;
const kGlfwKeyNumLock: u32 = 282;
const kGlfwKeyPrintScreen: u32 = 283;
const kGlfwKeyPause: u32 = 284;
const kGlfwKeyF1: u32 = 290;
const kGlfwKeyF2: u32 = 291;
const kGlfwKeyF3: u32 = 292;
const kGlfwKeyF4: u32 = 293;
const kGlfwKeyF5: u32 = 294;
const kGlfwKeyF6: u32 = 295;
const kGlfwKeyF7: u32 = 296;
const kGlfwKeyF8: u32 = 297;
const kGlfwKeyF9: u32 = 298;
const kGlfwKeyF10: u32 = 299;
const kGlfwKeyF11: u32 = 300;
const kGlfwKeyF12: u32 = 301;
const kGlfwKeyF13: u32 = 302;
const kGlfwKeyF14: u32 = 303;
const kGlfwKeyF15: u32 = 304;
const kGlfwKeyF16: u32 = 305;
const kGlfwKeyF17: u32 = 306;
const kGlfwKeyF18: u32 = 307;
const kGlfwKeyF19: u32 = 308;
const kGlfwKeyF20: u32 = 309;
const kGlfwKeyF21: u32 = 310;
const kGlfwKeyF22: u32 = 311;
const kGlfwKeyF23: u32 = 312;
const kGlfwKeyF24: u32 = 313;
const kGlfwKeyF25: u32 = 314;
const kGlfwKeyKp0: u32 = 320;
const kGlfwKeyKp1: u32 = 321;
const kGlfwKeyKp2: u32 = 322;
const kGlfwKeyKp3: u32 = 323;
const kGlfwKeyKp4: u32 = 324;
const kGlfwKeyKp5: u32 = 325;
const kGlfwKeyKp6: u32 = 326;
const kGlfwKeyKp7: u32 = 327;
const kGlfwKeyKp8: u32 = 328;
const kGlfwKeyKp9: u32 = 329;
const kGlfwKeyKpDecimal: u32 = 330;
const kGlfwKeyKpDivide: u32 = 331;
const kGlfwKeyKpMultiply: u32 = 332;
const kGlfwKeyKpSubtract: u32 = 333;
const kGlfwKeyKpAdd: u32 = 334;
const kGlfwKeyKpEnter: u32 = 335;
const kGlfwKeyKpEqual: u32 = 336;
const kGlfwKeyLeftShift: u32 = 340;
const kGlfwKeyLeftControl: u32 = 341;
const kGlfwKeyLeftAlt: u32 = 342;
const kGlfwKeyLeftSuper: u32 = 343;
const kGlfwKeyRightShift: u32 = 344;
const kGlfwKeyRightControl: u32 = 345;
const kGlfwKeyRightAlt: u32 = 346;
const kGlfwKeyRightSuper: u32 = 347;
const kGlfwKeyMenu: u32 = 348;

lazy_static! {
    static ref keycode_to_glfwkey_map: HashMap<u32, u32> = {
        HashMap::from([
            (KEY_GRAVE as u32, kGlfwKeyGraveAccent),
            (KEY_1 as u32, kGlfwKey1),
            (KEY_2 as u32, kGlfwKey2),
            (KEY_3 as u32, kGlfwKey3),
            (KEY_4 as u32, kGlfwKey4),
            (KEY_5 as u32, kGlfwKey5),
            (KEY_6 as u32, kGlfwKey6),
            (KEY_7 as u32, kGlfwKey7),
            (KEY_8 as u32, kGlfwKey8),
            (KEY_9 as u32, kGlfwKey9),
            (KEY_0 as u32, kGlfwKey0),
            (KEY_SPACE as u32, kGlfwKeySpace),
            (KEY_MINUS as u32, kGlfwKeyMinus),
            (KEY_EQUAL as u32, kGlfwKeyEqual),
            (KEY_Q as u32, kGlfwKeyQ),
            (KEY_W as u32, kGlfwKeyW),
            (KEY_E as u32, kGlfwKeyE),
            (KEY_R as u32, kGlfwKeyR),
            (KEY_T as u32, kGlfwKeyT),
            (KEY_Y as u32, kGlfwKeyY),
            (KEY_U as u32, kGlfwKeyU),
            (KEY_I as u32, kGlfwKeyI),
            (KEY_O as u32, kGlfwKeyO),
            (KEY_P as u32, kGlfwKeyP),
            (KEY_LEFTBRACE as u32, kGlfwKeyLeftBracket),
            (KEY_RIGHTBRACE as u32, kGlfwKeyRightBracket),
            (KEY_A as u32, kGlfwKeyA),
            (KEY_S as u32, kGlfwKeyS),
            (KEY_D as u32, kGlfwKeyD),
            (KEY_F as u32, kGlfwKeyF),
            (KEY_G as u32, kGlfwKeyG),
            (KEY_H as u32, kGlfwKeyH),
            (KEY_J as u32, kGlfwKeyJ),
            (KEY_K as u32, kGlfwKeyK),
            (KEY_L as u32, kGlfwKeyL),
            (KEY_SEMICOLON as u32, kGlfwKeySemicolon),
            (KEY_APOSTROPHE as u32, kGlfwKeyApostrophe),
            (KEY_Z as u32, kGlfwKeyZ),
            (KEY_X as u32, kGlfwKeyX),
            (KEY_C as u32, kGlfwKeyC),
            (KEY_V as u32, kGlfwKeyV),
            (KEY_B as u32, kGlfwKeyB),
            (KEY_N as u32, kGlfwKeyN),
            (KEY_M as u32, kGlfwKeyM),
            (KEY_COMMA as u32, kGlfwKeyComma),
            (KEY_DOT as u32, kGlfwKeyPeriod),
            (KEY_SLASH as u32, kGlfwKeySlash),
            (KEY_BACKSLASH as u32, kGlfwKeyBackslash),
            (KEY_ESC as u32, kGlfwKeyEscape),
            (KEY_TAB as u32, kGlfwKeyTab),
            (KEY_LEFTSHIFT as u32, kGlfwKeyLeftShift),
            (KEY_RIGHTSHIFT as u32, kGlfwKeyRightShift),
            (KEY_LEFTCTRL as u32, kGlfwKeyLeftControl),
            (KEY_RIGHTCTRL as u32, kGlfwKeyRightControl),
            (KEY_LEFTALT as u32, kGlfwKeyLeftAlt),
            (KEY_RIGHTALT as u32, kGlfwKeyRightAlt),
            (KEY_LEFTMETA as u32, kGlfwKeyLeftSuper),
            (KEY_RIGHTMETA as u32, kGlfwKeyRightSuper),
            (KEY_MENU as u32, kGlfwKeyMenu),
            (KEY_NUMLOCK as u32, kGlfwKeyNumLock),
            (KEY_CAPSLOCK as u32, kGlfwKeyCapsLock),
            (KEY_PRINT as u32, kGlfwKeyPrintScreen),
            (KEY_SCROLLLOCK as u32, kGlfwKeyScrollLock),
            (KEY_PAUSE as u32, kGlfwKeyPause),
            (KEY_DELETE as u32, kGlfwKeyDelete),
            (KEY_BACKSPACE as u32, kGlfwKeyBackspace),
            (KEY_ENTER as u32, kGlfwKeyEnter),
            (KEY_HOME as u32, kGlfwKeyHome),
            (KEY_END as u32, kGlfwKeyEnd),
            (KEY_PAGEUP as u32, kGlfwKeyPageUp),
            (KEY_PAGEDOWN as u32, kGlfwKeypageDown),
            (KEY_INSERT as u32, kGlfwKeyInsert),
            (KEY_LEFT as u32, kGlfwKeyLeft),
            (KEY_RIGHT as u32, kGlfwKeyRight),
            (KEY_DOWN as u32, kGlfwKeyDown),
            (KEY_UP as u32, kGlfwKeyUp),
            (KEY_F1 as u32, kGlfwKeyF1),
            (KEY_F2 as u32, kGlfwKeyF2),
            (KEY_F3 as u32, kGlfwKeyF3),
            (KEY_F4 as u32, kGlfwKeyF4),
            (KEY_F5 as u32, kGlfwKeyF5),
            (KEY_F6 as u32, kGlfwKeyF6),
            (KEY_F7 as u32, kGlfwKeyF7),
            (KEY_F8 as u32, kGlfwKeyF8),
            (KEY_F9 as u32, kGlfwKeyF9),
            (KEY_F10 as u32, kGlfwKeyF10),
            (KEY_F11 as u32, kGlfwKeyF11),
            (KEY_F12 as u32, kGlfwKeyF12),
            (KEY_F13 as u32, kGlfwKeyF13),
            (KEY_F14 as u32, kGlfwKeyF14),
            (KEY_F15 as u32, kGlfwKeyF15),
            (KEY_F16 as u32, kGlfwKeyF16),
            (KEY_F17 as u32, kGlfwKeyF17),
            (KEY_F18 as u32, kGlfwKeyF18),
            (KEY_F19 as u32, kGlfwKeyF19),
            (KEY_F20 as u32, kGlfwKeyF20),
            (KEY_F21 as u32, kGlfwKeyF21),
            (KEY_F22 as u32, kGlfwKeyF22),
            (KEY_F23 as u32, kGlfwKeyF23),
            (KEY_F24 as u32, kGlfwKeyF24),
            (KEY_KPSLASH as u32, kGlfwKeyKpDivide),
            (KEY_KPDOT as u32, kGlfwKeyKpMultiply),
            (KEY_KPMINUS as u32, kGlfwKeyKpSubtract),
            (KEY_KPPLUS as u32, kGlfwKeyKpAdd),
            (KEY_KP0 as u32, kGlfwKeyKp0),
            (KEY_KP1 as u32, kGlfwKeyKp1),
            (KEY_KP2 as u32, kGlfwKeyKp2),
            (KEY_KP3 as u32, kGlfwKeyKp3),
            (KEY_KP4 as u32, kGlfwKeyKp4),
            (KEY_KP5 as u32, kGlfwKeyKp5),
            (KEY_KP6 as u32, kGlfwKeyKp6),
            (KEY_KP7 as u32, kGlfwKeyKp7),
            (KEY_KP8 as u32, kGlfwKeyKp8),
            (KEY_KP9 as u32, kGlfwKeyKp9),
            (KEY_KPCOMMA as u32, kGlfwKeyKpDecimal),
            (KEY_KPEQUAL as u32, kGlfwKeyKpEqual),
            (KEY_KPENTER as u32, kGlfwKeyKpEnter),
        ])
    };
}
