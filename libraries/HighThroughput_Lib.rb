# By: Eriberto Lopez
# elopez3@uw.edu

# This library contains functions that aid in yeast high throughput screening.
# Ie: Calculations, formatting collections, etc...


needs "Standard Libs/AssociationManagement"
needs "Standard Libs/MatrixTools"

module HighThroughput_Lib
    include AssociationManagement, MatrixTools
    include PartProvenance
    
    # Finds where an alpha_coordinate is in a 96 Well plate
    #
    # @params alpha_coord [array or string] can be a single alpha_coordinate or a list of alpha_coordinate strings ie: 'A1' or ['A1','H7']
    # @return rc_list [Array] a list of [r,c] coordinates that describe where the alpha_coord(s) are in a 96 well matrix
    def find_rc_from_alpha_coord(alpha_coord)
        # look for where alpha coord is 2-D array coord
        coordinates_96 = ('a'..'h').to_a.map {|row| (1..12).to_a.map {|col| row + col.to_s}} 
        rc_list = []
        if alpha_coord.instance_of? Array
            alpha_coord = alpha_coord.map {|a| a.downcase}
            alpha_coord.each {|a_coord|
                coordinates_96.map.each_with_index { |row, r_idx| row.each_index.select {|col| row[col] == a_coord}.each { |c_idx| rc_list.push([r_idx, c_idx]) } } 
            }
        else
            coordinates_96.map.each_with_index { |row, r_idx| row.each_index.select {|col| row[col] == alpha_coord.downcase}.each { |c_idx| rc_list.push([r_idx, c_idx]) } }
        end
        return rc_list
    end
    
    # Fills collection matrix with sample_ids based on how many biological replicates requested
    #
    # @params collection [collection] collection to be filled with biological replicates
    # @params items [array] an array of items that biological replicates will be taken from
    # @params bio_reps [integer] comes from protocol parameter altered to an integer 
    # @return collection [collection] filled collection with same dimensions
    def fill_collection_mat(collection, items, bio_reps)
      items.each do |item|
        colony_num = 0
        item_associations = AssociationMap.new(item)
        bio_reps.times do
          r, c, x = collection.add_one(item.sample_id)
          part = collection.part(r, c)
          part_associations = AssociationMap.new(part)

          # record historical relation between item and target collection part, using PartProvenance
          add_provenance({
                           from: item,
                           from_map: item_associations,
                           to: part,
                           to_map: part_associations,
                           additional_relation_data: { source_colony: colony_num, process: "resuspension" }
                         })
          part_associations.save
          colony_num += 1
        end
        item_associations.save
      end
      return collection
    end
    
    def alpha_coords_96_matrix()
        ('a'..'h').to_a.map {|row| (1..12).to_a.map {|col| row + col.to_s}}
    end
    
    # Empty collection matrix
    #
    # @params collection [collection] collection you wish to empty
    # @return collection [collection] emptied collection with same dimensions
    def blank_collection_mat(collection)
        # empty out_coll
        rc_list = collection.get_non_empty
        rc_list.map {|r,c| collection.set(r,c,-1)}
        return collection
    end


end # Module

