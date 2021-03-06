#=
ported from:
http://docs.ros.org/jade/api/convex_decomposition/html/triangulate_8cpp_source.html

The MIT License (MIT)

Copyright (c) 2006 John W. Ratcliff

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
=#
"""
    area(vertices::AbstractVector{AbstractPoint{3}}, face::TriangleFace)

Calculate the area of one triangle.
"""
function area(vertices::AbstractVector{<:AbstractPoint{3, VT}}, face::TriangleFace{FT}) where {VT,FT}
    v1, v2, v3 = vertices[face]
    return 0.5 * norm(orthogonal_vector(v1, v2, v3))
end

"""
    area(vertices::AbstractVector{AbstractPoint{3}}, faces::AbstractVector{TriangleFace})

Calculate the area of all triangles.
"""
function area(
        vertices::AbstractVector{<:AbstractPoint{3, VT}},
        faces::AbstractVector{TriangleFace{FT}}
    ) where {VT,FT}
    return sum(x->area(vertices, x), faces)
end

function area(contour::AbstractVector{<:AbstractPoint{N, T}}) where {N, T}
    n = length(contour)
    n < 3 && return zero(T)
    A = zero(T)
    p = lastindex(contour)
    q = firstindex(contour)
    while q <= n
        A += cross(contour[p], contour[q])
        p = q; q +=1
    end
    return A * T(0.5)
end

function area(contour::AbstractVector{Point{3, T}}) where {T}
    A = zero(eltype(contour))
    o = contour[1]
    for i in (firstindex(contour)+1):(lastindex(contour)-1)
        A += cross(contour[i] - o, contour[i+1] - o)
    end
    return norm(A)*T(0.5)
end

"""
    in(point, triangle)

 InsideTriangle decides if a point P is Inside of the triangle
 defined by A, B, C.
"""
function Base.in(P::T, triangle::Triangle) where T <: AbstractPoint
    A, B, C = coordinates(triangle)
    a = C .- B
    b = A .- C
    c = B .- A

    ap = P .- A
    bp = P .- B
    cp = P .-C

    a_bp = a[1] * bp[2] - a[2] * bp[1]
    c_ap = c[1] * ap[2] - c[2] * ap[1]
    b_cp = b[1] * cp[2] - b[2] * cp[1]

    t0 = zero(eltype(T))

    return ((a_bp >= t0) && (b_cp >= t0) && (c_ap >= t0))
end

function snip(
        contour::AbstractVector{<: AbstractPoint{N, T}}, u, v, w, n, V
    ) where {N, T}
    A = contour[V[u]]
    B = contour[V[v]]
    C = contour[V[w]]
    x = (
        ((B[1]-A[1])*(C[2]-A[2])) -
        ((B[2]-A[2])*(C[1]-A[1]))
    )
    if 0.0000000001f0 > x
        return false
    end

    for p = 1:n
        ((p == u) || (p == v) || (p == w)) && continue;
        P = contour[V[p]]
        if P in Triangle(A, B, C)
            return false;
        end
    end
    return true;
end

"""
    faces(contour::AbstractArray{Point}, [facetype = GLTriangleFace])

Triangulates a Polygon given as an `AbstractArray{Point}` without holes.
It will return a Vector{`facetype`}, defining indexes into `contour`
"""
function decompose(::Type{FaceType}, points::AbstractArray{P}) where {P<:AbstractPoint, FaceType <: AbstractFace}
    #= allocate and initialize list of Vertices in polygon =#
    result = FaceType[]

    # the algorithm doesn't like closed contours
    contour = if isapprox(last(points), first(points))
        @view points[1:end-1]
    else
        @view points[1:end]
    end

    n = length(contour)
    if n < 3
        error("Not enough points in the contour. Found: $contour")
    end

    #= we want a counter-clockwise polygon in V =#
    if 0 < area(contour)
        V = Int[i for i=1:n]
    else
        V = Int[i for i=n:-1:1]
    end

    nv = n

    #=  remove nv-2 Vertices, creating 1 triangle every time =#
    count = 2*nv   #= error detection =#
    v = nv
    while nv > 2
        #= if we loop, it is probably a non-simple polygon =#
        if 0 >= count
            return result
        end
        count -= 1

        #= three consecutive vertices in current polygon, <u,v,w> =#
        u = v; (u > nv) && (u = 1) #= previous =#
        v = u+1; (v > nv) && (v = 1) #= new v =#
        w = v+1; (w > nv) && (w = 1) #= next =#
        if snip(contour, u, v, w, nv, V)
            #= true names of the vertices =#
            a = V[u]; b = V[v]; c = V[w];
            #= output Triangle =#
            push!(result, convert_simplex(FaceType, TriangleFace(a, b, c))...)
            #= remove v from remaining polygon =#
            s = v; t = v+1
            while t<=nv
                V[s] = V[t]
                s += 1; t += 1
            end
            nv -= 1
            #= resest error detection counter =#
            count = 2*nv
        end
    end

    return result
end
