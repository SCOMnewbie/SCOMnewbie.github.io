# Use on a Powershell shell
docker run --rm -it --volume="${pwd}:/srv/jekyll" -p 4000:4000 jekyll/jekyll jekyll serve