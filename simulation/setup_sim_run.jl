##################################################################
#* Load Packages
##################################################################
@info "Loading Packages"
using Pumas
using Serialization, StableRNGs, Random, StatsBase
using DataFramesMeta, Dates, ShiftedArrays, CategoricalArrays
using CairoMakie, AlgebraOfGraphics

##################################################################
#* Set output directory (OUTDIR)
##################################################################
@info "Set output directory"
# based on current UTC datetime (YYYY-MM-DDT:H:M:S) with ms removed
# way to consistently name folders in simulation/runs results/ automatically
OUTDIR = string(now())[begin:end-4];
@info "OUTDIR = $OUTDIR"

##################################################################
#* Copy sim template to OUTDIR 
##################################################################
@info "Copying template simulation files to OUTDIR"
cp("simulation/template", joinpath("simulation/runs",OUTDIR));

##################################################################
#* Create outdir in results folder
##################################################################
@info "Adding OUTDIR to results folder"
mkpath(joinpath("results", OUTDIR));