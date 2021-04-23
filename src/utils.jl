" Don't overflow the typemax. "
safeadd(x::T, y::T) where {T} = ifelse(x + y ≥ x, x + y, typemax(T))


"
Randomize sequence of length `n` from `letters`.
"
function getSeq(n = 20, letters = ['A', 'C', 'G', 'T'])
    return LongDNASeq(randstring(letters, n))
end


function base_to_idx(letter::Char)
    if letter == 'A'
        return 1
    elseif letter == 'C'
        return 2
    elseif letter == 'T'
        return 3
    elseif letter == 'G'
        return 4
    end
end


"
Get file extension from the string path `s`.
"
function extension(s::String)
    extension = match(r"\.[A-Za-z0-9]+$", s)
    if extension !== nothing
        return extension.match
    else
        return ""
    end
end


"
Returns smallest possible Unsigned type that can contain
given `max_value`.
"
function smallestutype(max_value::Unsigned)
    if typemax(UInt8) >= max_value
        return UInt8
    elseif typemax(UInt16) >= max_value
        return UInt16
    elseif typemax(UInt32) >= max_value
        return UInt32
    elseif typemax(UInt64) >= max_value
        return UInt64
    elseif typemax(UInt128) >= max_value
        return UInt128
    else
        throw("Too big unsigned value to fit in our types.")
    end
end


"
Create a list of possible strings of distance d
toward the string s. Don't include combinations 
which are smaller than d.
'-' in alphabet will be treated as indel.

TODO test this extensively...
"
function comb_of_d(s::String, d::Int = 1, alphabet::Vector{Char} = ['A', 'C', 'T', 'G'])
    s_ = collect(s)
    allcomb = Set{String}()
    idx_in_s = combinations(1:length(s), d)
    alphabet_comb = multiset_permutations(repeat(vcat(alphabet, ['-']), d), d)
    for i in idx_in_s
        for j in alphabet_comb
            if all(s_[i] .!= j)
                is_gap = j .== '-'
                i_not_gap = i[.!is_gap]
                i_gap = i[is_gap]
                if any(is_gap)
                    scopy = copy(s_)
                    scopy[i_not_gap] = j[.!is_gap]
                    alphabet_comb_for_gap = multiset_permutations(repeat(alphabet, length(i_gap)), length(i_gap))

                    scopy_new = copy(scopy)
                    deleteat!(scopy_new, i_gap)
                    for k in alphabet_comb_for_gap
                        
                        # gap in the s -> we insert base at the index and truncate to the size
                        scopy_s_ = copy(scopy)
                        for (w, kw) in enumerate(k)
                            insert!(scopy_s_, (i_gap[w] + w - 1), kw)
                        end
                        push!(allcomb, join(scopy_s_[1:length(s)]))
                        # gap in the new string -> we delete base at the index and add base at the end
                        scopy_new_ = copy(scopy_new)
                        append!(scopy_new_, k)
                        push!(allcomb, join(scopy_new_))
                    end
                else
                    scopy = copy(s_)
                    scopy[i] = j
                    push!(allcomb, join(scopy))
                end
            end
        end
    end
    # for now we need this - suboptimal method
    allcomb = collect(allcomb)
    dist = [levenshtein(LongDNASeq(s), LongDNASeq(x), d) == d for x in allcomb]
    return allcomb[dist]
end


"
Pidgeon hole principle: minimum
k-mer size that is required for two strings of
size `len` to be aligned within distance of `d`.
"
function minkmersize(len::Int = 20, d::Int = 4)
    return Int(floor(len / (d + 1)))
end


####### OLD functions
"
Write vector to file in binary format. This is being
serialized which means it can be read back only by the
same version of julia. Will remove file if it exists
before writing.
"
function file_write(write_path::String, vec::Vector)
    # make sure to delete content of write path first
    rm(write_path, force = true)
    io = open(write_path, "w")
    s = Serializer(io)
    for i in vec
        serialize(s, i)
    end
    close(io)
    return nothing
end

"
Read serialized vector from binary file. It can be read
back only by the same version of julia as when used during saving.
"
function file_read(read_path::String)
    x = Vector()
    io = open(read_path, "r")
    s = Serializer(io)
    while !eof(io)
        push!(x, deserialize(s))
    end
    close(io)
    return x
end

"
Append value to file in binary format. This is being
serialized which means it can be read back only by the
same version of julia.
"
function file_add(write_path::String, value)
    io = open(write_path, "a")
    s = Serializer(io)
    serialize(s, value)
    close(io)
end

"
    Will try to find value in `x` that will allow for almost equal
    split of values into buckets.
"
function balance(x::Vector{Int})
    if isempty(x)
        return nothing
    end
    uniq = unique(x)
    sort!(uniq)
    counts = [count(y -> y == i, x) for i in uniq]
    balance = argmin(abs.([sum(counts[1:i]) - sum(counts[i:end]) for i = 1:length(counts)]))
    return uniq[argmin(abs.(uniq .- uniq[balance]))]
end

"
Provides with the bucket path for guides and distances to parent.
"
function bucket_path(dir::String, idx::Int)
    gp = joinpath(dir, string("bucket_", idx, "_g.bin"))
    dp = joinpath(dir, string("bucket_", idx, "_d.bin"))
    return gp, dp
end
