# Unofficial Armbian for the Futurehome cube-2v0-eu smarthub
The contents in this repository is provided "as-is", without any warranties of
any kind.

The essence of this repository is basically a Makefile which pulls down and amends the
[Armbian build framework](https://github.com/armbian/build) with contents from the
[Futurehome cube-2v0-eu board support repo](https://github.com/RockPaperPencil/futurehome-cube2v0eu-boardsupport).

## Building
Just running **make** starts a build of the Armbian main branch with the *current*
kernel. Check out the Makefile for all the details!

Built images appears in the folder armbian-build/output/images.