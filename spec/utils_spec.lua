local utils = require "lustre.utils"
local cosock = require "cosock"
describe("utils", function()
    describe("validate_utf8", function()
        it("will validate `κόσ`  #o", function()
            assert(utils.validate_utf8("κόσ"))
        end)
        it("will validate querty #e", function()
            local querty = "`1234567890-=~!@#$%^&*()_+ qwertyuiop[]\\QWERTYUIOP{}|asdfghjkl;'ASDFGHJKL:\"zxcvbnm,./ZXCVBNM<>?"
            local idx = 0
            for ch in string.gmatch(querty, '.') do
                idx = idx + 1
                local s, e = utils.validate_utf8(ch)
                assert(s, string.format("failed to validate query char: %q: %s", ch, e))
            end
            local s, e = utils.validate_utf8(querty)
            assert(s, string.format("failed to validate full querty set: %s", e))
        end)
        it("will validate emoji faces", function()
            local faces = "😃🐻🍔⚽🌇💡🔣🎌😃😀😃😄😁😆😅🤣😂🙂🙃😉😊😇🥰😍🤩😘😗☺️😚😙🥲😋😛😜🤪😝🤑🤗🤭🤫🤔🤐🤨😐😑😶😶‍🌫️😏😒🙄😬😮‍💨🤥😌😔😪🤤😴😷🤒🤕🤢🤮🤧🥵🥶🥴😵😵‍💫🤯🤠🥳🥸😎🤓🧐😕😟🙁☹️😮😯😲😳🥺😦😧😨😰😥😢😭😱😖😣😞😓😩😫🥱😤😡😠🤬😈👿💀☠️💩🤡👹👺👻👽👾🤖😺😸😹😻😼😽🙀😿😾💋👋🤚🖐️✋🖖👌🤌🤏✌️🤞🤟🤘🤙👈👉👆🖕👇☝️👍👎✊👊🤛🤜👏🙌👐🤲🤝🙏✍️💅🤳💪🦾🦿🦵🦶👂🦻👃🧠🫀🫁🦷🦴👀👁️👅👄👶🧒👦👧🧑👱👨🧔👨‍🦰👨‍🦱👨‍🦳👨‍🦲👩👩‍🦰🧑‍🦰👩‍🦱🧑‍🦱👩‍🦳🧑‍🦳👩‍🦲🧑‍🦲👱‍♀️👱‍♂️🧓👴👵🙍🙍‍♂️🙍‍♀️🙎🙎‍♂️🙎‍♀️🙅🙅‍♂️🙅‍♀️🙆🙆‍♂️🙆‍♀️💁💁‍♂️💁‍♀️🙋🙋‍♂️🙋‍♀️🧏🧏‍♂️🧏‍♀️🙇🙇‍♂️🙇‍♀️🤦🤦‍♂️🤦‍♀️🤷🤷‍♂️🤷‍♀️🧑‍⚕️👨‍⚕️👩‍⚕️🧑‍🎓👨‍🎓👩‍🎓🧑‍🏫👨‍🏫👩‍🏫🧑‍⚖️👨‍⚖️👩‍⚖️🧑‍🌾👨‍🌾👩‍🌾🧑‍🍳👨‍🍳👩‍🍳🧑‍🔧👨‍🔧👩‍🔧🧑‍🏭👨‍🏭👩‍🏭🧑‍💼👨‍💼👩‍💼🧑‍🔬👨‍🔬👩‍🔬🧑‍💻👨‍💻👩‍💻🧑‍🎤👨‍🎤👩‍🎤🧑‍🎨👨‍🎨👩‍🎨🧑‍✈️👨‍✈️👩‍✈️🧑‍🚀👨‍🚀👩‍🚀🧑‍🚒👨‍🚒👩‍🚒👮👮‍♂️👮‍♀️🕵️🕵️‍♂️🕵️‍♀️💂💂‍♂️💂‍♀️🥷👷👷‍♂️👷‍♀️🤴👸👳👳‍♂️👳‍♀️👲🧕🤵🤵‍♂️🤵‍♀️👰👰‍♂️👰‍♀️🤰🤱👩‍🍼👨‍🍼🧑‍🍼👼🎅🤶🧑‍🎄🦸🦸‍♂️🦸‍♀️🦹🦹‍♂️🦹‍♀️🧙🧙‍♂️🧙‍♀️🧚🧚‍♂️🧚‍♀️🧛🧛‍♂️🧛‍♀️🧜🧜‍♂️🧜‍♀️🧝🧝‍♂️🧝‍♀️🧞🧞‍♂️🧞‍♀️🧟🧟‍♂️🧟‍♀️💆💆‍♂️💆‍♀️💇💇‍♂️💇‍♀️🚶🚶‍♂️🚶‍♀️🧍🧍‍♂️🧍‍♀️🧎🧎‍♂️🧎‍♀️🧑‍🦯👨‍🦯👩‍🦯🧑‍🦼👨‍🦼👩‍🦼🧑‍🦽👨‍🦽👩‍🦽🏃🏃‍♂️🏃‍♀️💃🕺🕴️👯👯‍♂️👯‍♀️🧖🧖‍♂️🧖‍♀️🧘🧑‍🤝‍🧑👭👫👬💏👩‍❤️‍💋‍👨👨‍❤️‍💋‍👨👩‍❤️‍💋‍👩💑👩‍❤️‍👨👨‍❤️‍👨👩‍❤️‍👩👪👨‍👩‍👦👨‍👩‍👧👨‍👩‍👧‍👦👨‍👩‍👦‍👦👨‍👩‍👧‍👧👨‍👨‍👦👨‍👨‍👧👨‍👨‍👧‍👦👨‍👨‍👦‍👦👨‍👨‍👧‍👧👩‍👩‍👦👩‍👩‍👧👩‍👩‍👧‍👦👩‍👩‍👦‍👦👩‍👩‍👧‍👧👨‍👦👨‍👦‍👦👨‍👧👨‍👧‍👦👨‍👧‍👧👩‍👦👩‍👦‍👦👩‍👧👩‍👧‍👦👩‍👧‍👧🗣️👤👥🫂👣🧳🌂☂️🎃🧵🧶👓🕶️🥽🥼🦺👔👕👖🧣🧤🧥🧦👗👘🥻🩱🩲🩳👙👚👛👜👝🎒🩴👞👟🥾🥿👠👡🩰👢👑👒🎩🎓🧢🪖⛑️💄💍💼🩸😃🐻🍔⚽🌇💡🔣🎌❤️✨🔥😊✔️😂👍🥰🥺🍎👀📈🎄💑🪟🦃🧔🇦🇺🇫🇷🎂🛍️✊🏿🇨🇦🇧🇷🐉🎅🇲🇽🦠🪔🇨🇳🌱🐰🎥🍂👨💪🌿🎓🔥🎃🕎💕🕉️🇺🇸♀️🤱🎊🔞🏊🏳️‍🌈🎭👑☪️🌱☘️☀️🏈🦃💘🎖️👰⛄🎿🏡⚽🌎"
            local s, e = utils.validate_utf8(faces)
            assert(s, string.format("failed to validate faces set: %s", e))
        end)
        it("will validate emoji flags", function()
            local flags = "🏁🚩🏴🏳️🏳️‍🌈🏳️‍⚧️🏴‍☠️🇦🇨🇦🇩🇦🇪🇦🇫🇦🇬🇦🇮🇦🇱🇦🇲🇦🇴🇦🇶🇦🇷🇦🇸🇦🇹🇦🇺🇦🇼🇦🇽🇦🇿🇧🇦🇧🇧🇧🇩🇧🇪🇧🇫🇧🇬🇧🇭🇧🇮🇧🇯🇧🇱🇧🇲🇧🇳🇧🇴🇧🇶🇧🇷🇧🇸🇧🇹🇧🇻🇧🇼🇧🇾🇧🇿🇨🇦🇨🇨🇨🇩🇨🇫🇨🇬🇨🇭🇨🇮🇨🇰🇨🇱🇨🇲🇨🇳🇨🇴🇨🇵🇨🇷🇨🇺🇨🇻🇨🇼🇨🇽🇨🇾🇨🇿🇩🇪🇩🇬🇩🇯🇩🇰🇩🇲🇩🇴🇩🇿🇪🇦🇪🇨🇪🇪🇪🇬🇪🇭🇪🇷🇪🇸🇪🇹🇪🇺🇫🇮🇫🇯🇫🇰🇫🇲🇫🇴🇫🇷🇬🇦🇬🇧🇬🇩🇬🇪🇬🇫🇬🇬🇬🇭🇬🇮🇬🇱🇬🇲🇬🇳🇬🇵🇬🇶🇬🇷🇬🇸🇬🇹🇬🇺🇬🇼🇬🇾🇭🇰🇭🇲🇭🇳🇭🇷🇭🇹🇭🇺🇮🇨🇮🇩🇮🇪🇮🇱🇮🇲🇮🇳🇮🇴🇮🇶🇮🇷🇮🇸🇮🇹🇯🇪🇯🇲🇯🇴🇯🇵🇰🇪🇰🇬🇰🇭🇰🇮🇰🇲🇰🇳🇰🇵🇰🇷🇰🇼🇰🇾🇰🇿🇱🇦🇱🇧🇱🇨🇱🇮🇱🇰🇱🇷🇱🇸🇱🇹🇱🇺🇱🇻🇱🇾🇲🇦🇲🇨🇲🇩🇲🇪🇲🇫🇲🇬🇲🇭🇲🇰🇲🇱🇲🇲🇲🇳🇲🇴🇲🇵🇲🇶🇲🇷🇲🇸🇲🇹🇲🇺🇲🇻🇲🇼🇲🇽🇲🇾🇲🇿🇳🇦🇳🇨🇳🇪🇳🇫🇳🇬🇳🇮🇳🇱🇳🇴🇳🇵🇳🇷🇳🇺🇳🇿🇴🇲🇵🇦🇵🇪🇵🇫🇵🇬🇵🇭🇵🇰🇵🇱🇵🇲🇵🇳🇵🇷🇵🇸🇵🇹🇵🇼🇵🇾🇶🇦🇷🇪🇷🇴🇷🇸🇷🇺🇷🇼🇸🇦🇸🇧🇸🇨🇸🇩🇸🇪🇸🇬🇸🇭🇸🇮🇸🇯🇸🇰🇸🇱🇸🇲🇸🇳🇸🇴🇸🇷🇸🇸🇸🇹🇸🇻🇸🇽🇸🇾🇸🇿🇹🇦🇹🇨🇹🇩🇹🇫🇹🇬🇹🇭🇹🇯🇹🇰🇹🇱🇹🇲🇹🇳🇹🇴🇹🇷🇹🇹🇹🇻🇹🇼🇹🇿🇺🇦🇺🇬🇺🇲🇺🇳🇺🇸🇺🇾🇺🇿🇻🇦🇻🇨🇻🇪🇻🇬🇻🇮🇻🇳🇻🇺🇼🇫🇼🇸🇽🇰🇾🇪🇾🇹🇿🇦🇿🇲🇿🇼🏴󠁧󠁢󠁥󠁮󠁧󠁿🏴󠁧󠁢󠁳󠁣󠁴󠁿🏴󠁧󠁢󠁷󠁬󠁳󠁿🏳‍🟧‍⬛‍🟧🏴󠁵󠁳󠁴󠁸󠁿😃🐻🍔⚽🌇💡🔣🎌❤️✨🔥😊✔️😂👍🥰🥺🍎👀📈🎄💑🪟🦃🧔🇦🇺🇫🇷🎂🛍️✊🏿🇨🇦🇧🇷🐉🎅🇲🇽🦠🪔🇨🇳🌱🐰🎥🍂👨💪🌿🎓🔥🎃🕎💕🕉️🇺🇸♀️🤱🎊🔞🏊🏳️‍🌈🎭👑☪️🌱☘️☀️🏈🦃💘🎖️👰⛄🎿🏡⚽🌎"
            local s, e = utils.validate_utf8(flags)
            assert(s, string.format("failed to validate faces set: %s", e))
        end)
        it("will validate cjk sample", function()
            local chars = "𠀀𠀁𠀂𠀃𠀄𠀅𠀆𠀇𠀈𠀉𠀊𠀋𠀌𠀍𠀎𠀏𠀐𠀑𠀒𠀓𠀔𠀕𠀖𠀗𠀘𠀙𠀚𠀛𠀜𠀝𠀞𠀟𠀠𠀡𠀢𠀣𠀤𠀥𠀦𠀧𠀨𠀩𠀪𠀫𠀬𠀭𠀮𠀯𠀰𠀱𠀲𠀳𠀴𠀵𠀶𠀷𠀸𠀹𠀺𠀻𠀼𠀽𠀾𠀿𠁀𠁁𠁂𠁃𠁄𠁅𠁆𠁇𠁈𠁉𠁊𠁋𠁌𠁍𠁎𠁏𠁐𠁑𠁒𠁓𠁔𠁕𠁖𠁗𠁘𠁙𠁚𠁛𠁜𠁝𠁞𠁟𠁠𠁡𠁢𠁣𠁤𠁥𠁦𠁧𠁨𠁩𠁪𠁫𠁬𠁭𠁮𠁯𠁰𠁱𠁲𠁳𠁴𠁵𠁶𠁷𠁸𠁹𠁺𠁻𠁼𠁽𠁾𠁿𠂀𠂁𠂂𠂃𠂄𠂅𠂆𠂇𠂈𠂉𠂊𠂋𠂌𠂍𠂎𠂏𠂐𠂑𠂒𠂓𠂔𠂕𠂖𠂗𠂘𠂙𠂚𠂛𠂜𠂝𠂞𠂟𠂠𠂡𠂢𠂣𠂤𠂥𠂦𠂧𠂨𠂩𠂪𠂫𠂬𠂭𠂮𠂯𠂰𠂱𠂲𠂳𠂴𠂵𠂶𠂷𠂸𠂹𠂺𠂻𠂼𠂽𠂾𠂿𠃀𠃁𠃂𠃃𠃄𠃅𠃆𠃇𠃈𠃉𠃊𠃋𠃌𠃍𠃎𠃏𠃐𠃑𠃒𠃓𠃔𠃕𠃖𠃗𠃘𠃙𠃚𠃛𠃜𠃝𠃞𠃟𠃠𠃡𠃢𠃣𠃤𠃥𠃦𠃧𠃨𠃩𠃪𠃫𠃬𠃭𠃮𠃯𠃰𠃱𠃲𠃳𠃴𠃵𠃶𠃷𠃸𠃹𠃺𠃻𠃼𠃽𠃾𠃿"
            local s, e = utils.validate_utf8(chars)
            assert(s, string.format("failed to validate cjk sample: %s", e))
        end)
        it("will validate `κόσμε`", function()
            local chars = "κόσμε"
            local s, e = utils.validate_utf8(chars)
            assert(s, string.format("failed to validate greek sample: %s", e))
        end)
        it("will fail `κόσμε���edited` #d", function()
            local input = string.char(0xce,0xba,0xe1,0xbd,0xb9,0xcf,0x83,0xce,0xbc,0xce,0xb5,0xed,0xa0,0x80,0x65,0x64,0x69,0x74,0x65,0x64)
            local success, error = utils.validate_utf8(input)
            assert(not success, string.format("expected to be valid %q", input))
        end)
        it("will fail invalid 4byte sequence in long bytes #v", function()
            local input = string.char(0xce,0xba,0xe1,0xbd,0xb9,0xcf,0x83,0xce,0xbc,0xce,0xb5,0xf4,0x90,0x80,0x80,0x65,0x64,0x69,0x74,0x65,0x64)
            local s, e = utils.validate_utf8(input)
            assert(not s)
        end)
        it("will fail two byte invalid continue", function()
            local inputs = {}
            for i = 0xC0, 0xDF do
                table.insert(inputs, {
                    value = string.char(i).." ",
                    error = "Invalid UTF-8 Sequence Continue"
                })
            end
            for _, input in ipairs(inputs) do
                local s, e = utils.validate_utf8(input.value)
                assert(not s, "Expected error in invalid two byte continue"..input.value)
            end
        end)
        it("will fail three byte invalid continue", function()
            local inputs = {}
            for i = 0xE0, 0xEF do
                table.insert(inputs, {
                    value = string.char(i).." ",
                    error = "Invalid UTF-8 Sequence Continue"
                })
            end
            for _, input in ipairs(inputs) do
                local s, e = utils.validate_utf8(input.value)
                assert(not s, "Expected error in invalid three byte continue"..input.value)
            end
        end)
        it("will fail four byte invalid continue", function()
            local inputs = {}
            for i = 0xF0, 0xF7 do
                table.insert(inputs, {
                    value = string.char(i).." ",
                    error = "Invalid UTF-8 Sequence Continue"
                })
            end
            for _, input in ipairs(inputs) do
                local s, e = utils.validate_utf8(input.value)
                assert(not s, "Expected error in invalid four byte continue"..input.value)
            end
        end)
        it("fails on single byte trailer", function()
            local s, e = utils.validate_utf8(string.char(0x80))
            assert(not s)
        end)
        it("returns nil for bad input #q", function()
            local inputs = {
                { value = string.char(0xBF), error = ""},
                { value = string.char(0xC0), error = ""},
                { value = string.char(0xE0), error = ""},
                { value = string.char(0xE0, 0x80), error = ""},
                { value = string.char(0xF0), error = ""},
                { value = string.char(0xF0, 0x80), error = ""},
                { value = string.char(0xF0, 0x80, 0x80), error = ""},
                { value = string.char(0xFE), error = ""},
                { value = string.char(0xFF), error = ""},
                { value = string.char(0xc0, 0xaf), error = ""},
              }
            for i, input in ipairs(inputs) do
                local success, error = utils.validate_utf8(input.value)
                assert(not success, string.format("%s expected to be invalid %s", i, input))
            end
        end)
        it("problematic 2 byte pair #r", function ()
            local success, error = utils.validate_utf8(string.char(0xc0, 0xaf))
            assert(not success)
            assert(error == "Invalid UTF-8 Length")
        end)
        it("too short 2 #B", function ()
            local slice = '\xce'
            local success, error, idx = utils.validate_utf8(slice)
            assert(not success)
            assert(idx == -1)
            assert(slice:sub(idx) == slice)
            assert(error == "Invalid UTF-8 too short", error)
        end)
        it("too short 3 #B", function ()
            local slice = '\xe0\xa0'
            local success, error, idx = utils.validate_utf8(slice)
            assert(not success)
            assert(idx == -2, "expected -2 found " .. tostring(idx))
            assert.are.same(slice:sub(idx), slice)
            assert(error == "Invalid UTF-8 too short", error)
        end)
        it("too short 4 #B", function ()
            local slice = '\xf0\x92\x83'
            local success, error, idx = utils.validate_utf8(slice)
            assert(not success)
            assert(idx == -3, "expected -3 found " .. tostring(idx))
            assert.are.same(slice:sub(idx), slice)
            assert(error == "Invalid UTF-8 too short", error)
        end)
        describe("validates in under 100s #w", function()
            it("4 * 2^20", function()
                local bytes = string.rep("abcd", 2^20)
                local s = os.time()
                assert(utils.validate_utf8(bytes))
                local e = os.time()
                assert(os.difftime(s, e) < 100, string.format("validating 4*2^20 bytes took >100 s %s", os.difftime(s, e)))
            end)
            -- it("16 * 2^20 #large-payload", function()
            --     local bytes = string.rep(
            --         string.rep("BAsd7&jh23", 2),
            --         2 ^ 20
            --     )
            --     bytes = string.sub(bytes, 1, 16 * 2 ^ 20)
            --     local s = os.time()
            --     assert(utils.validate_utf8(bytes))
            --     local e = os.time()
            --     assert(os.difftime(s, e) < 100, string.format("validating 16*2^20 bytes took >100 s %s", os.difftime(s, e)))
            -- end)
        end)
    end)
end)
