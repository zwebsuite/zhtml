const std = @import("std");

const zhtml = @import("./src/zhtml.zig");
const HTMLParser = zhtml.Parser;

const vexlib = @import("vexlib");
const println = vexlib.println;

pub fn main() void {
    // setup allocator
    var generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = generalPurposeAllocator.deinit();
    const allocator = generalPurposeAllocator.allocator();
    vexlib.init(&allocator);

    const htmlFile = @embedFile("./test/test.html");

    var myParser = HTMLParser{};
    const ast = myParser.parse(htmlFile) catch |err| blk: {
        switch (err) {
            error.ExpectedEndOfComment => {
                println("ExpectedEndOfComment");
            },
            error.ExpectedEndOfOpeningTag => {
                println("ExpectedEndOfOpeningTag");
            },
        }
        break :blk zhtml.Document{
            .version = undefined,
            .children = undefined
        };
    };
    
    // std.debug.print("AST:\n{any}\n", .{ast});
    println("BEFORE:");
    println(htmlFile);

    var stringified = zhtml.stringify(ast);
    defer stringified.dealloc();
    println("AFTER:");
    println(stringified);

    zhtml.deallocAST(ast);
}
