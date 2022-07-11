import sys
from docx import Document
import contextlib


def main(input_path, output_path):

    """
    Below is copied and pasted with zero improvements from my repl. I see no urgent reason to improve it but it's
    obviously very improvable.
    """

    doc = Document(input_path)
    with smart_open(output_path if output_path != "print" else None) as fh:

        styles_copy = {
            "latent": {
                s.name.replace(" ", "").lower(): {"children": [], "name": s.name}
                for s in doc.styles.latent_styles
            },
            "wrong_style_type": {},
            "base_style_not_found": {},
        }
        for style in doc.styles:
            styleId = style.element.get(
                "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}styleId"
            )
            styleType = style.element.get(
                "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}type"
            )
            if styleType not in styles_copy:
                styles_copy[styleType] = {}
            styles_copy[styleType][styleId] = {"id": styleId, "children": []}
            for (
                child
            ) in (
                style.element.iter()
            ):  # xpath in python-docx require a simple work around (because of the namespaces)
                # I didn't feel like looking up
                if (
                    child.tag
                    == "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}link"
                ):
                    styles_copy[styleType][styleId]["link"] = child.get(
                        "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val"
                    )
                if (
                    child.tag
                    == "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}basedOn"
                ):
                    styles_copy[styleType][styleId]["basedOn"] = child.get(
                        "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val"
                    )
                if (
                    child.tag
                    == "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}name"
                ):
                    styles_copy[styleType][styleId]["name"] = child.get(
                        "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val"
                    )

        moved = {}
        for style_type in styles_copy:
            for style in styles_copy[style_type]:
                if "basedOn" in styles_copy[style_type][style]:
                    bo = styles_copy[style_type][style]["basedOn"]
                    if bo in styles_copy[style_type]:
                        styles_copy[style_type][bo]["children"].append(
                            styles_copy[style_type][style]
                        )
                    elif bo.lower() in styles_copy["latent"]:
                        styles_copy["latent"][bo]["children"].append(
                            styles_copy[style_type][style]
                        )
                    else:
                        for inner_style_type in styles_copy:
                            if bo in styles_copy[inner_style_type]:
                                if bo not in styles_copy["wrong_style_type"]:
                                    styles_copy["wrong_style_type"][bo] = {
                                        "children": [],
                                        "styleId": bo,
                                        "style_type": style_type,
                                        "points_to": inner_style_type,
                                    }
                                styles_copy["wrong_style_type"][bo]["children"].append(
                                    styles_copy[style_type][style]
                                )

                        if bo not in styles_copy["wrong_style_type"]:
                            if bo not in styles_copy["base_style_not_found"]:
                                styles_copy["base_style_not_found"][bo] = {
                                    "children": [],
                                    "styleId": bo,
                                }

                            styles_copy["base_style_not_found"][bo]["children"].append(
                                styles_copy[style_type][style]
                            )

                    if style_type not in moved:
                        moved[style_type] = []
                    moved[style_type].append(style)

        for mtype in moved:
            for ms in moved[mtype]:
                styles_copy[mtype].pop(ms)

        for t in styles_copy:
            printable_title = t.title().replace("_", " ")
            if len(styles_copy[t]) > 0:
                print(f"* {printable_title}", file=fh)
                for s in styles_copy[t]:
                    print_style(styles_copy[t][s], 1, fh)
            else:
                print(f"-> Skipping {printable_title} because its empty")


def print_style(style, iterator, fh):

    print(
        "{}* {} {} {} {}".format(
            "  " * iterator,
            style["name"] if "name" in style else style["styleId"],
            f"basedOn: {style['basedOn']}" if "basedOn" in style else "",
            f"link {style['link']}" if "link" in style else "",
            f"Style Type: {style['style_type']} Points To: {style['points_to']}"
            if "style_type" in style
            else "",
        ),
        file=fh,
    )
    if len(style["children"]) > 0:
        [print_style(s, iterator + 1, fh) for s in style["children"]]


# from https://stackoverflow.com/questions/17602878/how-to-handle-both-with-open-and-sys-stdout-nicely
@contextlib.contextmanager
def smart_open(filename=None):
    if filename and filename != "-":
        fh = open(filename, "w")
    else:
        fh = sys.stdout
    try:
        yield fh
    finally:
        if fh is not sys.stdout:
            fh.close()


if __name__ == "__main__":
    input_path = "reference.docx"
    output_path = "print"

    if len(sys.argv) == 2:
        input_path = sys.argv[1] if sys.argv[1].endswith(".docx") else "reference.docx"
        output_path = sys.argv[1] if sys.argv[1].endswith(".md") else "print"
        output_path = sys.argv[1] if sys.argv[1] == "print" else output_path
    elif len(sys.argv) == 3:
        input_path = sys.argv[1] if sys.argv[1].endswith(".docx") else sys.argv[2]
        output_path = (
            sys.argv[2]
            if sys.argv[2].endswith(".md") or sys.argv[2] == "print"
            else sys.argv[2]
        )

    if (
        not output_path.endswith(".md") and output_path != "print"
    ) or not input_path.endswith(".docx"):
        raise Exception(
            f"Input path is {input_path} (needs to be *.docx) and output path is {output_path} (needs to be *.md or print."
        )

    main(input_path, output_path)
