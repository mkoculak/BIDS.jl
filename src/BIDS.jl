module BIDS

import CSV
import JSON3
import Tables: dictrowtable
import DataFrames: DataFrames, DataFrame, Not, select!, mapcols!
import DataStructures: SortedDict, OrderedDict
import Logging: global_logger, NullLogger, Warn
import LoggingExtras: TeeLogger, TransformerLogger, EarlyFilteredLogger

const BIDSVersion = "1.8.0"

include("file_browser.jl")
export Layout, browse

include("agnostic.jl")
export Description

include("modalities.jl")
include("modalities/EEG.jl")

include("helpers.jl")
export show_warnings

include("dataset.jl")
export Dataset

include("get_data.jl")
export get_data

end #module