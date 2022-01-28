local utils = require "lustre.utils"

describe("utils", function()
    describe("validate_utf8", function()
        it("returns 1 for good input", function()
            local inputs = {
                "`1234567890-=~!@#$%^&*()_+ qwertyuiop[]\\QWERTYUIOP{}|asdfghjkl;'ASDFGHJKL:\"zxcvbnm,./ZXCVBNM<>?",
                "😃🐻🍔⚽🌇💡🔣🎌😃😀😃😄😁😆😅🤣😂🙂🙃😉😊😇🥰😍🤩😘😗☺️😚😙🥲😋😛😜🤪😝🤑🤗🤭🤫🤔🤐🤨😐😑😶😶‍🌫️😏😒🙄😬😮‍💨🤥😌😔😪🤤😴😷🤒🤕🤢🤮🤧🥵🥶🥴😵😵‍💫🤯🤠🥳🥸😎🤓🧐😕😟🙁☹️😮😯😲😳🥺😦😧😨😰😥😢😭😱😖😣😞😓😩😫🥱😤😡😠🤬😈👿💀☠️💩🤡👹👺👻👽👾🤖😺😸😹😻😼😽🙀😿😾💋👋🤚🖐️✋🖖👌🤌🤏✌️🤞🤟🤘🤙👈👉👆🖕👇☝️👍👎✊👊🤛🤜👏🙌👐🤲🤝🙏✍️💅🤳💪🦾🦿🦵🦶👂🦻👃🧠🫀🫁🦷🦴👀👁️👅👄👶🧒👦👧🧑👱👨🧔👨‍🦰👨‍🦱👨‍🦳👨‍🦲👩👩‍🦰🧑‍🦰👩‍🦱🧑‍🦱👩‍🦳🧑‍🦳👩‍🦲🧑‍🦲👱‍♀️👱‍♂️🧓👴👵🙍🙍‍♂️🙍‍♀️🙎🙎‍♂️🙎‍♀️🙅🙅‍♂️🙅‍♀️🙆🙆‍♂️🙆‍♀️💁💁‍♂️💁‍♀️🙋🙋‍♂️🙋‍♀️🧏🧏‍♂️🧏‍♀️🙇🙇‍♂️🙇‍♀️🤦🤦‍♂️🤦‍♀️🤷🤷‍♂️🤷‍♀️🧑‍⚕️👨‍⚕️👩‍⚕️🧑‍🎓👨‍🎓👩‍🎓🧑‍🏫👨‍🏫👩‍🏫🧑‍⚖️👨‍⚖️👩‍⚖️🧑‍🌾👨‍🌾👩‍🌾🧑‍🍳👨‍🍳👩‍🍳🧑‍🔧👨‍🔧👩‍🔧🧑‍🏭👨‍🏭👩‍🏭🧑‍💼👨‍💼👩‍💼🧑‍🔬👨‍🔬👩‍🔬🧑‍💻👨‍💻👩‍💻🧑‍🎤👨‍🎤👩‍🎤🧑‍🎨👨‍🎨👩‍🎨🧑‍✈️👨‍✈️👩‍✈️🧑‍🚀👨‍🚀👩‍🚀🧑‍🚒👨‍🚒👩‍🚒👮👮‍♂️👮‍♀️🕵️🕵️‍♂️🕵️‍♀️💂💂‍♂️💂‍♀️🥷👷👷‍♂️👷‍♀️🤴👸👳👳‍♂️👳‍♀️👲🧕🤵🤵‍♂️🤵‍♀️👰👰‍♂️👰‍♀️🤰🤱👩‍🍼👨‍🍼🧑‍🍼👼🎅🤶🧑‍🎄🦸🦸‍♂️🦸‍♀️🦹🦹‍♂️🦹‍♀️🧙🧙‍♂️🧙‍♀️🧚🧚‍♂️🧚‍♀️🧛🧛‍♂️🧛‍♀️🧜🧜‍♂️🧜‍♀️🧝🧝‍♂️🧝‍♀️🧞🧞‍♂️🧞‍♀️🧟🧟‍♂️🧟‍♀️💆💆‍♂️💆‍♀️💇💇‍♂️💇‍♀️🚶🚶‍♂️🚶‍♀️🧍🧍‍♂️🧍‍♀️🧎🧎‍♂️🧎‍♀️🧑‍🦯👨‍🦯👩‍🦯🧑‍🦼👨‍🦼👩‍🦼🧑‍🦽👨‍🦽👩‍🦽🏃🏃‍♂️🏃‍♀️💃🕺🕴️👯👯‍♂️👯‍♀️🧖🧖‍♂️🧖‍♀️🧘🧑‍🤝‍🧑👭👫👬💏👩‍❤️‍💋‍👨👨‍❤️‍💋‍👨👩‍❤️‍💋‍👩💑👩‍❤️‍👨👨‍❤️‍👨👩‍❤️‍👩👪👨‍👩‍👦👨‍👩‍👧👨‍👩‍👧‍👦👨‍👩‍👦‍👦👨‍👩‍👧‍👧👨‍👨‍👦👨‍👨‍👧👨‍👨‍👧‍👦👨‍👨‍👦‍👦👨‍👨‍👧‍👧👩‍👩‍👦👩‍👩‍👧👩‍👩‍👧‍👦👩‍👩‍👦‍👦👩‍👩‍👧‍👧👨‍👦👨‍👦‍👦👨‍👧👨‍👧‍👦👨‍👧‍👧👩‍👦👩‍👦‍👦👩‍👧👩‍👧‍👦👩‍👧‍👧🗣️👤👥🫂👣🧳🌂☂️🎃🧵🧶👓🕶️🥽🥼🦺👔👕👖🧣🧤🧥🧦👗👘🥻🩱🩲🩳👙👚👛👜👝🎒🩴👞👟🥾🥿👠👡🩰👢👑👒🎩🎓🧢🪖⛑️💄💍💼🩸😃🐻🍔⚽🌇💡🔣🎌❤️✨🔥😊✔️😂👍🥰🥺🍎👀📈🎄💑🪟🦃🧔🇦🇺🇫🇷🎂🛍️✊🏿🇨🇦🇧🇷🐉🎅🇲🇽🦠🪔🇨🇳🌱🐰🎥🍂👨💪🌿🎓🔥🎃🕎💕🕉️🇺🇸♀️🤱🎊🔞🏊🏳️‍🌈🎭👑☪️🌱☘️☀️🏈🦃💘🎖️👰⛄🎿🏡⚽🌎",
                "🏁🚩🏴🏳️🏳️‍🌈🏳️‍⚧️🏴‍☠️🇦🇨🇦🇩🇦🇪🇦🇫🇦🇬🇦🇮🇦🇱🇦🇲🇦🇴🇦🇶🇦🇷🇦🇸🇦🇹🇦🇺🇦🇼🇦🇽🇦🇿🇧🇦🇧🇧🇧🇩🇧🇪🇧🇫🇧🇬🇧🇭🇧🇮🇧🇯🇧🇱🇧🇲🇧🇳🇧🇴🇧🇶🇧🇷🇧🇸🇧🇹🇧🇻🇧🇼🇧🇾🇧🇿🇨🇦🇨🇨🇨🇩🇨🇫🇨🇬🇨🇭🇨🇮🇨🇰🇨🇱🇨🇲🇨🇳🇨🇴🇨🇵🇨🇷🇨🇺🇨🇻🇨🇼🇨🇽🇨🇾🇨🇿🇩🇪🇩🇬🇩🇯🇩🇰🇩🇲🇩🇴🇩🇿🇪🇦🇪🇨🇪🇪🇪🇬🇪🇭🇪🇷🇪🇸🇪🇹🇪🇺🇫🇮🇫🇯🇫🇰🇫🇲🇫🇴🇫🇷🇬🇦🇬🇧🇬🇩🇬🇪🇬🇫🇬🇬🇬🇭🇬🇮🇬🇱🇬🇲🇬🇳🇬🇵🇬🇶🇬🇷🇬🇸🇬🇹🇬🇺🇬🇼🇬🇾🇭🇰🇭🇲🇭🇳🇭🇷🇭🇹🇭🇺🇮🇨🇮🇩🇮🇪🇮🇱🇮🇲🇮🇳🇮🇴🇮🇶🇮🇷🇮🇸🇮🇹🇯🇪🇯🇲🇯🇴🇯🇵🇰🇪🇰🇬🇰🇭🇰🇮🇰🇲🇰🇳🇰🇵🇰🇷🇰🇼🇰🇾🇰🇿🇱🇦🇱🇧🇱🇨🇱🇮🇱🇰🇱🇷🇱🇸🇱🇹🇱🇺🇱🇻🇱🇾🇲🇦🇲🇨🇲🇩🇲🇪🇲🇫🇲🇬🇲🇭🇲🇰🇲🇱🇲🇲🇲🇳🇲🇴🇲🇵🇲🇶🇲🇷🇲🇸🇲🇹🇲🇺🇲🇻🇲🇼🇲🇽🇲🇾🇲🇿🇳🇦🇳🇨🇳🇪🇳🇫🇳🇬🇳🇮🇳🇱🇳🇴🇳🇵🇳🇷🇳🇺🇳🇿🇴🇲🇵🇦🇵🇪🇵🇫🇵🇬🇵🇭🇵🇰🇵🇱🇵🇲🇵🇳🇵🇷🇵🇸🇵🇹🇵🇼🇵🇾🇶🇦🇷🇪🇷🇴🇷🇸🇷🇺🇷🇼🇸🇦🇸🇧🇸🇨🇸🇩🇸🇪🇸🇬🇸🇭🇸🇮🇸🇯🇸🇰🇸🇱🇸🇲🇸🇳🇸🇴🇸🇷🇸🇸🇸🇹🇸🇻🇸🇽🇸🇾🇸🇿🇹🇦🇹🇨🇹🇩🇹🇫🇹🇬🇹🇭🇹🇯🇹🇰🇹🇱🇹🇲🇹🇳🇹🇴🇹🇷🇹🇹🇹🇻🇹🇼🇹🇿🇺🇦🇺🇬🇺🇲🇺🇳🇺🇸🇺🇾🇺🇿🇻🇦🇻🇨🇻🇪🇻🇬🇻🇮🇻🇳🇻🇺🇼🇫🇼🇸🇽🇰🇾🇪🇾🇹🇿🇦🇿🇲🇿🇼🏴󠁧󠁢󠁥󠁮󠁧󠁿🏴󠁧󠁢󠁳󠁣󠁴󠁿🏴󠁧󠁢󠁷󠁬󠁳󠁿🏳‍🟧‍⬛‍🟧🏴󠁵󠁳󠁴󠁸󠁿😃🐻🍔⚽🌇💡🔣🎌❤️✨🔥😊✔️😂👍🥰🥺🍎👀📈🎄💑🪟🦃🧔🇦🇺🇫🇷🎂🛍️✊🏿🇨🇦🇧🇷🐉🎅🇲🇽🦠🪔🇨🇳🌱🐰🎥🍂👨💪🌿🎓🔥🎃🕎💕🕉️🇺🇸♀️🤱🎊🔞🏊🏳️‍🌈🎭👑☪️🌱☘️☀️🏈🦃💘🎖️👰⛄🎿🏡⚽🌎",
                "𠀀𠀁𠀂𠀃𠀄𠀅𠀆𠀇𠀈𠀉𠀊𠀋𠀌𠀍𠀎𠀏𠀐𠀑𠀒𠀓𠀔𠀕𠀖𠀗𠀘𠀙𠀚𠀛𠀜𠀝𠀞𠀟𠀠𠀡𠀢𠀣𠀤𠀥𠀦𠀧𠀨𠀩𠀪𠀫𠀬𠀭𠀮𠀯𠀰𠀱𠀲𠀳𠀴𠀵𠀶𠀷𠀸𠀹𠀺𠀻𠀼𠀽𠀾𠀿𠁀𠁁𠁂𠁃𠁄𠁅𠁆𠁇𠁈𠁉𠁊𠁋𠁌𠁍𠁎𠁏𠁐𠁑𠁒𠁓𠁔𠁕𠁖𠁗𠁘𠁙𠁚𠁛𠁜𠁝𠁞𠁟𠁠𠁡𠁢𠁣𠁤𠁥𠁦𠁧𠁨𠁩𠁪𠁫𠁬𠁭𠁮𠁯𠁰𠁱𠁲𠁳𠁴𠁵𠁶𠁷𠁸𠁹𠁺𠁻𠁼𠁽𠁾𠁿𠂀𠂁𠂂𠂃𠂄𠂅𠂆𠂇𠂈𠂉𠂊𠂋𠂌𠂍𠂎𠂏𠂐𠂑𠂒𠂓𠂔𠂕𠂖𠂗𠂘𠂙𠂚𠂛𠂜𠂝𠂞𠂟𠂠𠂡𠂢𠂣𠂤𠂥𠂦𠂧𠂨𠂩𠂪𠂫𠂬𠂭𠂮𠂯𠂰𠂱𠂲𠂳𠂴𠂵𠂶𠂷𠂸𠂹𠂺𠂻𠂼𠂽𠂾𠂿𠃀𠃁𠃂𠃃𠃄𠃅𠃆𠃇𠃈𠃉𠃊𠃋𠃌𠃍𠃎𠃏𠃐𠃑𠃒𠃓𠃔𠃕𠃖𠃗𠃘𠃙𠃚𠃛𠃜𠃝𠃞𠃟𠃠𠃡𠃢𠃣𠃤𠃥𠃦𠃧𠃨𠃩𠃪𠃫𠃬𠃭𠃮𠃯𠃰𠃱𠃲𠃳𠃴𠃵𠃶𠃷𠃸𠃹𠃺𠃻𠃼𠃽𠃾𠃿",
                "κόσμε",
                string.char(0xce,0xba,0xe1,0xbd,0xb9,0xcf,0x83,0xce,0xbc,0xce,0xb5,0xed,0xa0,0x80,0x65,0x64,0x69,0x74,0x65,0x64),
            }
            for _, input in ipairs(inputs) do
                local success, error = utils.validate_utf8(input)
                assert(success, string.format("expected to be valid %q\n%q", input, error))
                print(input)
            end
        end)
        it("returns nil for bad input #q", function()
            local inputs = {
                { value = string.char(0x80), error = "Invalid UTF-8 Sequence Start"},
                { value = string.char(0xBF), error = "Invalid UTF-8 Sequence Start"},
                { value = string.char(0xC0), error = "UTF-8 Sequence Too Short"},
                { value = string.char(0xE0), error = "UTF-8 Sequence Too Short"},
                { value = string.char(0xE0, 0x80), error = "UTF-8 Sequence Too Short"},
                { value = string.char(0xF0), error = "UTF-8 Sequence Too Short"},
                { value = string.char(0xF0, 0x80), error = "UTF-8 Sequence Too Short"},
                { value = string.char(0xF0, 0x80, 0x80), error = "UTF-8 Sequence Too Short"},
                { value = string.char(0xFE), error = "Invalid UTF-8 Byte"},
                { value = string.char(0xFF), error = "Invalid UTF-8 Byte"},
              }
            -- 2 byte invalid continue
            for i = 0xC0, 0xDF do
                table.insert(inputs, {
                    value = string.char(i).." ",
                    error = "Invalid UTF-8 Sequence Continue"
                })
            end
            -- 3 byte invalid continue
            for i = 0xE0, 0xEF do
                table.insert(inputs, {
                    value = string.char(i).."  ",
                    error = "Invalid UTF-8 Sequence Continue"
                })
            end
            -- 4 byte invalid continue
            for i = 0xF0, 0xF7 do
                table.insert(inputs, {
                    value = string.char(i).."   ",
                    error = "Invalid UTF-8 Sequence Continue"
                })
            end
            for i, input in ipairs(inputs) do
                local success, error = utils.validate_utf8(input.value)
                assert(not success, string.format("%s expected to be invalid %q\n%q", i, input.value, error))
                assert(error == input.error, string.format("%s Expected %q found %q", i, input.error, error or "nil"))
                -- assert.are.same(error, input.error)
            end
        end)
    end)
end)