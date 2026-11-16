# gds_png.py - render a GDSII file to a PNG without opening the KLayout window
# Run:  klayout -zz -rd gds=<file.gds> -rd lyp=<file.lyp> -rd out=<file.png> -r scripts/gds_png.py
import pya
view = pya.LayoutView()
view.load_layout(gds, True)
view.load_layer_props(lyp)
view.max_hier()
view.set_config("background-color", "#ffffff")
view.set_config("text-visible", "false")
view.set_config("inst-label-visible", "false")
view.zoom_fit()
view.save_image(out, 1600, 1600)
