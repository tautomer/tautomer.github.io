import argparse
import os
import shutil
import sys


class CustomFormatter(
    argparse.ArgumentDefaultsHelpFormatter, argparse.RawTextHelpFormatter
):
    """Formatter for the help message of the argument parser"""

    pass


parser = argparse.ArgumentParser(formatter_class=CustomFormatter)

parser.add_argument(
    "-p",
    "--post",
    type=str,
    help="Path to the the html or markdown source of the post",
)

parser.add_argument(
    "-i",
    "--image",
    type=str,
    help="Path to the image that will be included in the homepage",
)

parser.add_argument(
    "-t",
    "--title",
    type=str,
    help="Title of the post showing up in the homepage\n"
    "If not provided, the script will try to get it from the post",
)

parser.add_argument(
    "-d",
    "--description",
    type=str,
    help="Description of the post showing up in the homepage\n"
    "If not provided, the script will try to get it from the post",
)

parser.add_argument(
    "-b",
    "--button",
    type=str,
    help="Text of the hyperlink button to the post showing up in the homepage\n"
    "If not provided, the script will use the title",
)

parser.add_argument(
    "--inplace",
    action="store_true",
    default=False,
    help="Overwrite the existing index.html with the updated one\n"
    "Otherwise index.html will remain untouched, and a new file called index.new.html is generated\n"
    "User can examine the new homepage and decide whether to use it",
)

args = parser.parse_args()

if not args.post:
    sys.exit("Path to the post must be provided")
# TODO: create a simple fill block with text if no image is provided
if not args.image:
    sys.exit("Path to the image must be provided")
if not args.title:
    read_title = True
else:
    read_title = False
if not args.description:
    read_des = True
else:
    read_des = False

try:
    post_path = os.path.realpath(args.post)
except Exception as e:
    sys.exit(f"Post {args.post} not exist or invalid. Error message {str(e)}")
try:
    img_path = os.path.realpath(args.image)
except Exception as e:
    sys.exit(f"Post {args.image} not exist or invalid. Error message {str(e)}")
cwd = os.path.realpath(os.getcwd())
root_dir = os.path.dirname(cwd)
# obtain the filename and strip the extension
# the resulting path should be like /posts/file_basename
post_rel_path = "/posts/" + ".".join(post_path.split("/")[-1].split(".")[:-1]) + "/"
img_rel_path = "/" + os.path.relpath(img_path, root_dir)

if read_title or read_des:
    with open(post_path, "r") as post:
        line = post.readline()
        # for this to work, the file must start with a yaml block
        if line[:3] != "---":
            raise ValueError(
                "The post does not contain the yaml block needed to read the title and description"
            )
        while True:
            line = post.readline()
            if line.startswith("title") and read_title:
                args.title = line.split(":")[1].strip()
                read_title = False
            elif line.startswith("description") and read_des:
                args.description = line.split(":")[1].strip()
                read_des = False
            elif line[:3] == "---":
                if read_title or read_des:
                    raise ValueError("The yaml block has no title or description")
                break
            # when EOF is encountered and yaml block is still not closed
            # very likely there is something wrong
            if not line:
                raise ValueError("Something wrong with the yaml block?")
if not args.button:
    args.button = args.title

# fmt off
html_code = f"""<!-- {args.title} -->
<div class="clearfix">
  <h2>{args.title}</h2>
  <div class="row d-flex justify-content-start">
    <div class="col-md-2 d-flex align-items-center">
      <a href="{post_rel_path}">
        <img class="rounded-4 img-fluid float-left mb-2" src="{img_rel_path}" alt="PPI" width="200"
          height="200">
      </a>
    </div>
    <div class="col-md-7 d-flex align-items-center table-responsive">
      <table>
        <tr>
          <td>
            <p>
              {args.description}
            </p>
          </td>
        </tr>
        <tr>
          <td>
            <div class="text-center">
              <a class="btn btn-outline-primary btn-block" href="{post_rel_path}" role="button">{args.button} 
                <i class="fa-solid fa-angles-right fa-sm"></i></a>
            </div>
          </td>
        </tr>
      </table>
    </div>
    <div class="col-md-3"></div>
  </div>
</div>"""
# fmt on

# add html
updated = False
new_index = f"{root_dir}/index.new.html"
old_index = f"{root_dir}/index.html"
out = open(new_index, "w")
with open(old_index, "r") as page:
    while True:
        line = page.readline()
        # if EOF encountered and the title is not found
        if not line:
            out.close()
            if not updated:
                os.remove(new_index)
                raise ValueError(
                    "Something wrong with index.html. Level 1 title not found. Nothing written"
                )
            break
        line = line.rstrip()
        print(line, file=out)
        # find the title line
        if "<h1>" in line:
            print("", file=out)
            print(html_code, file=out)
            updated = True


if args.inplace:
    shutil.move(new_index, old_index)
