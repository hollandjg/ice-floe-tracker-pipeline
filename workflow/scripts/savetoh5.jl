#!/usr/bin/env julia
using Pkg
Pkg.activate(joinpath(@__DIR__, "../..")) # activate project environment

using DataFrames
using Dates
using HDF5
using IFTPipeline
using PyCall
using Serialization

function getiftversion()
    deps = Pkg.dependencies()
    iftversion = ""
    for (_, dep) in deps
        dep.is_direct_dep || continue
        dep.version === nothing && continue
        dep.name != "IceFloeTracker" && continue
        iftversion = dep.version
    end
    maj = Int(iftversion.major)
    min = Int(iftversion.minor)
    patch = Int(iftversion.patch)
    "v$maj.$min.$patch"
end


function makeh5filename(imgfname)
    replace(imgfname, "truecolor" => "labeled_image", "tiff" => "h5")
end

"""
    convertcentroid!(propdf, latlondata, colstodrop)

Convert the centroid coordinates from row and column to latitude and longitude. Also drop the columns specified in `colstodrop`.
"""
function convertcentroid!(propdf, latlondata, colstodrop)
    latitude, longitude = [
        [
            latlondata[c][Int(round(_x)), Int(round(_y))]]
        for (_x, _y) in zip(propdf.row_centroid, propdf.col_centroid)
        for c in ["latitude", "longitude"]
    ]
    propdf.latitude = latitude
    propdf.longitude = longitude
    dropcols!(propdf, colstodrop)
end

function dropcols!(df, colstodrop)
    select!(df, Not(colstodrop))
    return nothing
end

function converttounits!(propdf, latlondata, colstodrop)
    if nrow(propdf) == 0
        dropcols!(propdf, colstodrop)
        return nothing
    end
    convertcentroid!(propdf, latlondata, colstodrop)
    x = latlondata["X"]
    dx = abs(x[2] - x[1])
    convertarea(area) = area * dx^2 / 1e6
    convertlength(length) = length * dx / 1e3
    propdf.area .= convertarea(propdf.area)
    propdf.convex_area .= convertarea(propdf.convex_area)
    propdf.minor_axis_length .= convertlength(propdf.minor_axis_length)
    propdf.major_axis_length .= convertlength(propdf.major_axis_length)
    propdf.perimeter .= convertlength(propdf.perimeter)
    return nothing
end

@pyinclude(joinpath(@__DIR__, "latlon.py"))

getlatlon = py"getlatlon"

"""
    makeh5file(pathtosampleimg, resdir)

Package the results of the IceFloeTracker pipeline in `resdir` into individual HDF5 files in `resdir/hdf5-files`. 

This function expects the following files to be present in `resdir`: `filenames.jls`, `passtimes.jls`, `segmented_floes.jls`, and `floe_props.jls`. These files are generated by the `IceFloeTracker` pipeline.

# Arguments:

  * `pathtosampleimg`: Path to a sample image. This is used to extract the coordinate reference system (CRS) and the latitude and longitude coordinates of the image pixels.
  * `resdir`: Path to the directory containing the results of the IceFloeTracker pipeline.

# File structure
Each HDF5 file has the following structure:

```
🗂️ HDF5.File: (read-only) YYYYMMDD.sat.labeled_image.250m.h5
├─ 🏷️ contact
├─ 🏷️ crs
├─ 🏷️ fname_reflectance
├─ 🏷️ fname_truecolor
├─ 🏷️ iftversion
├─ 🏷️ reference
├─ 📂 floe_properties
│  ├─ 🏷️ Description of labeled_image
│  ├─ 🏷️ Description of properties
│  ├─ 🔢 colunm_names
│  ├─ 🔢 labeled_image
│  └─ 🔢 properties
└─ 📂 index
   ├─ 🔢 latitude
   ├─ 🔢 longitude
   ├─ 🔢 time
   ├─ 🔢 x
   └─ 🔢 y
```
# The `floe_properties` and `index` group

The `floe_properties` group contains a floe properties matrix `properties` for `labeled_image` and assciated `colunm_names`.

The `index` group contains the latitude and longitude coordinates (see the description of properties within the file for an account of the units of each property), and satellite pass time `time` in Unix time that captured the source image.

"""
function makeh5file(pathtosampleimg, resdir)

    latlondata = getlatlon(pathtosampleimg)

    iftversion = getiftversion()

    ptpath = joinpath(resdir, "passtimes.jls")
    passtimes = deserialize(ptpath)
    ptsunix = Int64.(Dates.datetime2unix.(passtimes))

    fnpath = joinpath(resdir, "filenames.jls")
    truecolor_refs, reflectance_refs = deserialize(fnpath)

    floespath = joinpath(resdir, "segmented_floes.jls")
    floes = deserialize(floespath)

    colstodrop = [:row_centroid, :col_centroid, :min_row, :min_col, :max_row, :max_col]
    propspath = joinpath(resdir, "floe_props.jls")
    props = deserialize(propspath)
    for df in props
        converttounits!(df, latlondata, colstodrop)
    end

    h5dir = joinpath(resdir, "hdf5-files")
    mkpath(h5dir)
    for (i, fname) in enumerate(truecolor_refs)
        fname = makeh5filename(fname)
        fnamepath = joinpath(h5dir, fname)
        h5open(fnamepath, "w") do file
            # Add top-level attributes
            attrs(file)["fname_reflectance"] = reflectance_refs[i]
            attrs(file)["fname_truecolor"] = truecolor_refs[i]
            attrs(file)["iftversion"] = iftversion
            attrs(file)["crs"] = latlondata["crs"]
            attrs(file)["reference"] = "https://doi.org/10.1016/j.rse.2019.111406"
            attrs(file)["contact"] = "mmwilhelmus@brown.edu"

            g = create_group(file, "index")
            g["time"] = Int64.(Dates.datetime2unix(passtimes[i]))
            g["x"] = latlondata["X"]
            g["y"] = latlondata["Y"]
            g["latitude"] = latlondata["latitude"]
            g["longitude"] = latlondata["longitude"]

            g = create_group(file, "floe_properties")
            g["properties"] = Matrix(props[i])
            attrs(g)["Description of properties"] = """Generated using the `regionprops` function from the `skimage` package. See https://scikit-image.org/docs/0.20.x/api/skimage.measure.html#regionprops

            Area units (`area`, `convex_area`) are in sq. kilometers, and length units (`minor_axis_length`, `major_axis_length`, and `perimeter`) are in kilometers, and `orientation` in radians (see the description of properties attribute.). Latitude and longitude coordinates are in degrees.
            """

            g["colunm_names"] = names(props[i])
            g["labeled_image"] = label_components(floes[i], trues(3, 3))
            attrs(g)["Description of labeled_image"] = "Connected components of the segmented floe image using a 3x3 structuring element. The property matrix consists of the properties of each connected component."
        end
    end
    return nothing
end
