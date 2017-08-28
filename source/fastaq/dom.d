/**
 * Mechanism to parse JSON data into a JSON object tree. Some aspects borrowed from std.json.
 */
module fastaq.dom;
import fastaq.parser;
import iopipe.traits;

enum FASTAQType
{
    Header,
    Sequence,
    Null,
}

struct FASTAQValue(SType)
{
    // basically a tagged union.
    FASTAQType type;
    union
    {
        string header;
        string[] sequence;
        FASTAQValue[SType] object;
        SType str;
        bool boolean;
    }
}

template parseFASTAQ(bool inPlace = false, bool duplicate = true, Chain)
{
    alias SType = WindowType!Chain;
    alias FaT = FASTAQValue!SType;
    struct DOMParser
    {
        FASTAQTokenizer!(Chain, inPlace) parser;
        FaT buildValue(FASTAQItem item)
        {
            switch (item.token) with (FASTAQToken)
            {
            case EntryStart:
                return buildObject();
            case Sequence:
                // See if we require copying.
                {
                    FaT result;
                    result.type = FASTAQType.String;
                    if(item.hint == FASTAQParserHint.InPlace)
                    {
                        static if(!duplicate)
                        {
                            // can just slice the string
                            result.str = item.data(parser.chain);
                            return result;
                        }
                        else
                        {
                            // need to copy anyway, but much easier than replacing escapes
                            result.str = cast(typeof(result.str))item.data(parser.chain).dup;
                            return result;
                        }
                    }
                    else
                    {
                        // put the quotes back
                        item.offset--;
                        item.length += 2;

                        // re-parse, this time replacing escapes. This is so ugly...
                        auto newpipe = item.data(parser.chain).dup;
                        size_t pos = 0;
                        item.length = parseString(newpipe, pos, item.hint);
                        ++item.offset;
                        result.str = cast(typeof(result.str))item.data(newpipe);
                        return result;
                    }
                }
            case Null:
                {
                    FaT result;
                    result.type = FASTAQType.Null;
                    return result;
                }
            default:
                throw new Exception("Error in FASTAQ data");
            }
        }



    }

    auto parseFASTAQ(Chain c)
    {
        auto dp = DOMParser(FASTAQTokenizer!(Chain, inPlace)(c));
        switch(dp.parser.next.token) with (FASTAQToken)
        {
        case EntryStart:
            return dp.buildObject();
        case ArrayStart:
            return dp.buildArray();
        default:
            throw new Exception("Expected object or array");
        }
    }
}

void printFastaq(FaT)(FaT item)
{
    import std.stdio;
    final switch(item.type) with (FASTAQType)
    {
    case Header:
        {
            write("{");
            bool first = true;
            foreach(n, v; item.object)
            {
                if(first)
                    first = false;
                else
                    write(", ");
                writef(`"%s" : `, n);
                printFastaq(v);
            }
            write("}");
        }
        break;
    case Null:
        write("null");
        break;
   case Sequence:
     //TODO: Enable wrapping of sequence to max N characters (i.e. 70)
        writef(`"%s"`, item.str);
        break;
    }
}

unittest
{
    auto fa = parseFASTAQ(q"{{"a" : [1, 2.5, "x", true, false, null]}}");
    //printFastaq(fa);
    auto fa2 = parseFASTAQ!(false, false)(q"{{"a" : [1, 2.5, "x", true, false, null]}}");
    //printFastaq(fa2);
}
