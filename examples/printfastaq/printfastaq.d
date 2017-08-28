import iopipe.stream;
import iopipe.bufpipe;
import iopipe.textpipe;
import iopipe.valve;
import fastaq.parser;
import iopipe.buffer;

void main(string[] args)
{
   // auto parser = openDev(args[1]).bufd.decodeText!(UTFType.UTF8).jsonTokenizer!false;

    import std.mmfile;
    scope mmf = new MmFile(args[1]);
    auto x = cast(immutable(char)[])mmf[];
    auto parser = x.faTokenizer!false;

    auto outputter = bufd!(char).push!(c => c
                                .encodeText!(UTFType.UTF8)
                                .outputPipe(openDev(1)));

    int spacing;
    enum indent = 4;
    void putIndent()
    {
        outputter.ensureElems(indent * spacing + 1);
        outputter.window[0] = '\n';
        outputter.window[1 .. 1+indent*spacing] = ' ';
        outputter.release(indent * spacing + 1);
    }

    void putStr(const(char)[] s)
    {
        outputter.ensureElems(s.length);
        outputter.window[0 .. s.length] = s;
        outputter.release(s.length);
    }

    auto item = parser.next;
    while(item.token != FASTAQToken.EOF)
    {
        with(FASTAQToken) final switch(item.token)
        {
        case EntryStart:
            ++spacing;
            putStr("{");
            putIndent();
            break;
        case Null:
            putStr(item.data(parser.chain));
            break;
        case Error:
        case EOF:
            putStr("***ERROR***");
            return;
        }

        item = parser.next;
    }
    putStr("\n");
}
