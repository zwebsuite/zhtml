// zcss - Pure Zig CSS Parser
// https://www.w3.org/TR/css-syntax-3/

const std = @import("std");
const vexlib = @import("vexlib");
const As = vexlib.As;
const Math = vexlib.Math;
const String = vexlib.String;
const Map = vexlib.Map;
const Array = vexlib.Array;
const fmt = vexlib.fmt;

const selfClosingTags = [_][]const u8{"area","base","br","col","command","embed","hr","img","input","keygen","link","meta","param","source","track","wbr"};

const ParseError = error {
    ExpectedEndOfComment,
    ExpectedEndOfOpeningTag
};

pub const Text = struct {
    innerHTML: String
};

pub const Element = struct {
    tag: String,
    attributes: Map(String, String),
    innerHTML: String,
    children: Array(ElementOrText)
};

const ElementOrText = union(enum) { 
    element: Element,
    text: Text
};

pub const Document = struct {
    version: u32,
    children: Array(ElementOrText)
};

fn isSelfClosingTag(tagName: []u8) bool {
    var i: usize = 0;
    while (i < selfClosingTags.len) : (i += 1) {
        if (std.mem.eql(u8, tagName, selfClosingTags[i])) {
            return true;
        }
    }
    return false;
}

fn parseAttributes(source: String) Map(String, String) {
    var attributes = Map(String, String).alloc();

    var idx: u32 = 0;
    while (idx < source.len()) {
        // has found start of attribute
        if (source.charAt(idx) != ' ') {
            // find end of key
            const keyStart = idx;
            idx += 1;
            while (source.charAt(idx) != ' ' and source.charAt(idx) != '=' and idx < source.len()) {
                idx += 1;
            }
            const key = source.slice(keyStart, idx);

            // find next token
            while (source.charAt(idx) == ' ' and idx < source.len()) {
                idx += 1;
            }

            // check if the next token is equal sign
            const hasValue = source.charAt(idx) == '=';
            if (hasValue) {
                idx += 1;
            }

            // find value
            if (hasValue) {
                while (source.charAt(idx) == ' ' and idx < source.len()) {
                    idx += 1;
                }
            }

            // parse value
            var value: String = undefined;
            if (source.charAt(idx) == '"') {
                // double quoted value
                idx += 1;
                const stringStart = idx;
                while (source.charAt(idx) != '"' and idx < source.len()) {
                    idx += 1;
                }
                value = source.slice(stringStart, idx);
            } else if (source.charAt(idx) == '\'') {
                // single quoted value
                idx += 1;
                const stringStart = idx;
                while (source.charAt(idx) != '\'' and idx < source.len()) {
                    idx += 1;
                }
                value = source.slice(stringStart, idx);
            } else if (hasValue) {
                // non-quoted value
                const stringStart = idx;
                while (source.charAt(idx) != ' ' and idx < source.len()) {
                    idx += 1;
                }
                value = source.slice(stringStart, idx);
            } else {
                // empty attribute
                idx -= 1;
                // TODO: revise potential source of memory leak
                value = String.alloc(0);
            }

            attributes.set(key, value);
        }
        idx += 1;
    }

    return attributes;
}

fn noStringIdxOf(str: String, targetStr: anytype, start: u32) i32 {
    var i = start;
    var inString = false;
    var strType: u8 = ' ';
    while (i < str.len()) {
        const c = str.charAt(i);
        if (c == '"' or c == '\'') {
            if (inString) {
                if (c == strType) {
                    inString = false;
                }
            } else {
                inString = true;
                strType = c;
            }
        }
        if (str.slice(i, i + As.u32(targetStr.len)).equals(targetStr) and !inString) {
            return As.i32(i);
        }
        i += 1;
    }
    return -1;
}

fn parseHTML(source: String) ParseError!Array(ElementOrText) {
    var elements = Array(ElementOrText).alloc(4);
    var idx: u32 = 0;
    var endOfLastComponent: u32 = 0;

    while (idx < source.len()) {
        // hit start of component
        if (source.charAt(idx) == '<') {
            if (source.charAt(idx+1) == '!') {
                const endCommentIdx = source.slice(idx, -1).indexOf("-->");
                if (endCommentIdx == -1) {
                    return ParseError.ExpectedEndOfComment;
                } else {
                    idx += As.u32(endCommentIdx) + 3;
                    endOfLastComponent = idx;
                }
            } else {
                // capture text node
                if (idx != endOfLastComponent) {
                    elements.append(ElementOrText{
                        .text = Text{
                            .innerHTML = source.slice(endOfLastComponent, idx)
                        }
                    });
                }

                vexlib.println("________________");
                vexlib.println(source.slice(idx, -1));
    
                // parse opening tag
                idx += 1; // skip less than character
                const temp = source.slice(idx, -1);
                const headerEndIdx = noStringIdxOf(temp, ">", 0);
                if (headerEndIdx == -1) {
                    return ParseError.ExpectedEndOfOpeningTag;
                }
                const componentHeader = temp.slice(0, As.u32(headerEndIdx));
                const isSelfClosing = componentHeader.charAt(componentHeader.len() - 1) == '/';
                
                // parse out tag name
                var tagEndIdx = componentHeader.indexOf(" ");
                if (tagEndIdx == -1) {
                    if (isSelfClosing) {
                        tagEndIdx = As.i32(componentHeader.len()) - 1;
                    } else {
                        tagEndIdx = As.i32(componentHeader.len());
                    }
                }
                const tagName = componentHeader.slice(0, As.u32(tagEndIdx));

                // increment idx to element's body
                idx += As.u32(headerEndIdx) + 1;

                vexlib.println("------------");
                vexlib.println(source.slice(idx, -1));
                
                // check if is a self closing tag type
                const isSelfClosingType = isSelfClosingTag(tagName.raw());

                // parse body
                var content: String = undefined;
                if (!isSelfClosing and !isSelfClosingType) {
                    content = source.slice(idx, -1);

                    // find index of closing tag
                    var closingIdx: u32 = 0;
                    var depth: u32 = 1;
                    while (depth != 0 and closingIdx < content.len()) {
                        const slc = content.slice(closingIdx, -1);

                        const startsWithLT = slc.charAt(0) == '<';
                        const slcMove1 = slc.slice(1, -1);
                        if (startsWithLT and slcMove1.startsWith(tagName)) {
                            depth += 1;
                        } else if (startsWithLT and slcMove1.charAt(0) == '/' and slcMove1.slice(1, -1).startsWith(tagName)) {
                            depth -= 1;
                        }

                        if (depth != 0) {
                            const nextOpening = noStringIdxOf(slc, "<", 1);
                            if (nextOpening == -1) {
                                break;
                            } else {
                                closingIdx += As.u32(nextOpening);
                            }
                        }
                    }

                    content = content.slice(0, closingIdx);

                    // increment idx to very end of element
                    idx += content.len() + (tagName.len() + 2 + 1);
                } else {
                    // TODO: revise potential source of memory leak
                    content = String.alloc(0);
                }

                var attribStr: String = undefined;
                if (isSelfClosing) {
                    attribStr = componentHeader.slice(As.u32(tagEndIdx), componentHeader.len() - 1);
                } else {
                    attribStr = componentHeader.slice(As.u32(tagEndIdx), componentHeader.len());
                }

                elements.append(ElementOrText{
                    .element = Element{
                        .tag = tagName,
                        .attributes = parseAttributes(attribStr),
                        .innerHTML = content,
                        .children = try parseHTML(content)
                    }
                });

                endOfLastComponent = idx;
            }
        } else {
            idx += 1;
        }
    }

    // capture remaining text node
    if (idx != endOfLastComponent) {
        elements.append(ElementOrText{
            .text = Text{
                .innerHTML = source.slice(endOfLastComponent, idx)
            }
        });
    }

    return elements;
}

pub const Parser = struct {
    // comments: Array(Comment) = undefined,

    pub fn parse(self: *Parser, html_: []const u8) ParseError!Document {
        _=self;
        var buff = Array(u8).using(@constCast(html_));
        buff.len = As.u32(html_.len);
        var source = String.using(buff);

        // only support HTML5 because what are you doing using HTML4 in 2024
        const HTML5DocType = "<!doctype html>";
        var doctype = source.trimStart().slice(0, HTML5DocType.len).clone();
        defer doctype.dealloc();
        doctype.lowerCase();
        var isHTML5 = false;
        if (doctype.equals(HTML5DocType)) {
            isHTML5 = true;
            source = source.slice(As.u32(source.indexOf('>') + 1), -1);
        }

        return Document{
            .version = if (isHTML5) 5 else 0,
            .children = try parseHTML(source)
        };
    }
};

fn deallocElement(element_: Element) void {
    var element = element_;

    var children = element.children;
    var i: u32 = 0;
    while (i < children.len) : (i += 1) {
        const child = children.get(i);
        switch (child) {
            .element => {
                deallocElement(child.element);
            },
            .text => {
                
            }
        }
    }

    element.attributes.dealloc();
    element.children.dealloc();
}

pub fn deallocAST(ast_: Document) void {
    var ast = ast_;

    var children = ast_.children;
    var i: u32 = 0;
    while (i < children.len) : (i += 1) {
        const child = children.get(i);
        switch (child) {
            .element => {
                deallocElement(child.element);
            },
            .text => {
                
            }
        }
    }

    ast.children.dealloc();
}

fn stringifyElement(element_: Element, indentAmt: u32) String {
    const element = element_;

    // var indentLevel = if (indentAmt == 0) String.allocFrom("    ") else String.allocFrom("        ");
    // defer indentLevel.dealloc();

    var out = String.allocFrom("<");
    out.concat(element.tag);
    out.concat('>');
    
    var children = element.children;
    var i: u32 = 0;
    while (i < children.len) : (i += 1) {
        const child = children.get(i);
        switch (child) {
            .element => {
                vexlib.println(child.element.tag);
                var elStr = stringifyElement(child.element, 0);
                defer elStr.dealloc();
                out.concat(elStr);
            },
            .text => {
                out.concat(child.text.innerHTML);
            }
        }
    }

    const isSelfClosingType = isSelfClosingTag(element.tag.raw());
    if (!isSelfClosingType) {
        out.concat("</");
        out.concat(element.tag);
        out.concat('>');
    }

    _=indentAmt;
    return out;
}

pub fn stringify(document: Document) String {
    var out = if (document.version == 5) String.allocFrom("<!DOCTYPE html>") else String.alloc(256);
    var children = document.children;
    var i: u32 = 0;
    while (i < children.len) : (i += 1) {
        const child = children.get(i);
        switch (child) {
            .element => {
                var elStr = stringifyElement(child.element, 0);
                defer elStr.dealloc();
                out.concat(elStr);
            },
            .text => {
                out.concat(child.text.innerHTML);
            }
        }
    }
    return out;
}