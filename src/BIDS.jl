module BIDS

import CSV
import JSON3
import Tables: dictrowtable
import DataFrames: DataFrames, DataFrame, Not, select!
import DataStructures: SortedDict, OrderedDict

const BIDSVersion = "1.8.0"

include("file_browser.jl")
export Layout, browse

include("modalities.jl")
include("EEG.jl")

include("agnostic.jl")
export Description

include("dataset.jl")
export Dataset

include("helpers.jl")

include("get_data.jl")
export get_data

end #module