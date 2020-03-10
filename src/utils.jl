export get_score

function get_score(values_sparce, values_dense)
    is, id = 1, 1
    ls, ld = length(values_sparce), length(values_dense)

    score = 0
    n = 1
    while (is < ls) && (id <= ld)
        vxs = values_sparce[is][1]
        vxd = values_dense[id][1]

        vys = values_sparce[is][2]
        vyd = values_dense[id][2]


        if vxd >= vxs
            gaps = values_sparce[is+1][1] - values_sparce[is][1]
            score += abs(vys-vyd)^2 * gaps
            is += 1
            n += 1
        end

        id += 1
    end

    gaps = values_sparce[end][1]-values_sparce[end-1][1]
    last_diff = abs(values_sparce[end][2]-values_dense[end][2])

    return -(score + last_diff^2 * gaps)
end
