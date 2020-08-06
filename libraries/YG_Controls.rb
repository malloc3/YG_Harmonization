# By: Eriberto Lopez
# elopez3@uw.edu
# Updated: 08/15/18
# This library is to help with creating additional controls to the YG_Harmonization workflow

needs 'Standard Libs/AssociationManagement'

module YG_Controls
    include AssociationManagement
    include PartProvenance
    
    def creating_neg_pos_wt_staining_control(in_collection, out_collection, output_cult_dest, cult_vol_mat, media_vol_mat, input_cult_coords, samp_id=22544) #Sync by OD
        if debug
            samp_id = 22544 # WT 22544 is not in Nursery 
        end
        # Finding where WT is on the input collection in order to copy cult and media vol for synchronization of WT controls
        input_wt_cult_coord = find_input_wt_cult_coord(collection=in_collection)
        # log_info 'input_wt_cult_coord creating control', input_wt_cult_coord
        
        # Found the coordinate in which wt is in now copy the media vol and the culture vol
        neg_pos_wt_cult_coord_destination = ['H7', 'H8'] # Where I want control cults to be in the output plate
        neg_pos_wt_cult_coord_destination = find_rc_from_alpha_coord(alpha_coord=neg_pos_wt_cult_coord_destination)
        neg_pos_stn_wt_cult_vol = input_wt_cult_coord.map {|r,c| cult_vol_mat[r][c]}.first
        neg_pos_stn_wt_media_vol = input_wt_cult_coord.map {|r,c| media_vol_mat[r][c]}.first
        neg_pos_wt_cult_coord_destination.each {|r,c|
            cult_vol_mat[r][c] = neg_pos_stn_wt_cult_vol
            media_vol_mat[r][c] = neg_pos_stn_wt_media_vol
            input_cult_coords.push([r, c])
            out_coll_matrix = out_collection.matrix 
            out_coll_matrix[r][c] = samp_id # sample_id Diploid WT
            out_collection.matrix = out_coll_matrix
            out_collection.save
        }
        
        return input_cult_coords, cult_vol_mat, media_vol_mat
    end
    
    
    def creating_pos_gfp_control(out_collection, input_plate_ods, final_output_vol, cult_vol_mat, media_vol_mat, input_cult_coords, samp_id=6390) # Sync by OD
        gfp_input_cult_coord = 'H9' # gfp culture is in the same place that it will be in the deep well experimental plate
        gfp_input_cult_coord_destination = find_rc_from_alpha_coord(alpha_coord=gfp_input_cult_coord)
        gfp_input_cult_vol, gfp_input_media_vol = sync_gfp_control(gfp_input_cult_coord=gfp_input_cult_coord, gfp_output_cult_coord=gfp_input_cult_coord, input_plate_ods, final_output_vol) #YG_Controls
        log_info 'gfp_input_cult_vol', gfp_input_cult_vol, 'gfp_input_media_vol',gfp_input_media_vol
        gfp_input_cult_coord_destination.each {|r,c|
            cult_vol_mat[r][c] = gfp_input_cult_vol
            media_vol_mat[r][c] = gfp_input_media_vol
            input_cult_coords.push([r, c])
            out_coll_matrix = out_collection.matrix 
            out_coll_matrix[r][c] = samp_id # sample_id NOR00 1.0
            out_collection.matrix = out_coll_matrix
            out_collection.save
        }
        return input_cult_coords, cult_vol_mat, media_vol_mat
    end
    
    # Will find where in a collection diploid WT is located and return [[r,c]]
    def find_input_wt_cult_coord(collection)
        wt_cult_coord = []
        collection.matrix.each_with_index.map {|row, r_idx|
            row.each_with_index.map {|col, c_idx|
                wt_sample_id = []
                if debug
                    wt_sample_id = [1, 30, 22544, 22801]
                else
                    wt_sample_id = [30, 22544, 22801]
                end
                
                # Once wt sample_id is found in the collection return [[r,c]]
                if wt_sample_id.include? col
                    wt_cult_coord.push([r_idx, c_idx])
                    break
                end
            }
        }
        return wt_cult_coord
    end

    
    # Will add a positive gfp colony (NOR00) to a desired well in a collection
    #
    # @params collection [collection obj] the collection to which the gfp control will be added to
    # @params well [string] the alpha numeric coordinate that the gfp colony will be added to
    # @returns need_to_create_new_control_plate[:make_new_plate] [boolean] will return true or false based on user input
    def adding_positive_gfp_control(collection, well='H9')
        strain_sample_id = 6390 # NOR_00 1.0
        obj_type = "Yeast Plate"
        # Find the plate created for the gfp positive control
        positive_gfp_control_plate = find(:item, { sample: { id: strain_sample_id }, object_type: { name: obj_type } } ).select {|item| 
            item.get('YG_Control') == 'positive_gfp'
        }.first # Key: YG_Control, Value: 'positive_gfp' - previously associated value to sample and item
        
        take [positive_gfp_control_plate], interactive: true
        
        display_rc_list = find_rc_from_alpha_coord(well)
        show do 
            title "Adding Positive GFP Control"
            separator
            note "To 96 Flat Bottom Plate <b>#{collection.id}</b>:"
            bullet "Fill <b>#{well}</b> with 200µl of liquid SC media"
            bullet "Pick colony from Yeast Plate <b>#{positive_gfp_control_plate.id}</b> & resuspend in the well highlighted below"
            table highlight_alpha_rc(collection, display_rc_list) {|r,c| "#{positive_gfp_control_plate.id}"}
            check "<b>Finally, place clear lid on top and tape shut before placing it on the plate shaker.</b>"
        end
        
        # Associate provenance data between control plate and collection
        control_plate_associations = AssociationMap.new(positive_gfp_control_plate)
        
        display_rc_list.each do |r, c|
            # Add control strain to collection
            collection_sample_matrix = collection.matrix
            collection_sample_matrix[r][c] = strain_sample_id
            collection.matrix = collection_sample_matrix 

            part = collection.part(r,c)
            part_associations = AssociationMap.new(part)
            add_provenance({
                           from: positive_gfp_control_plate,
                           from_map: control_plate_associations,
                           to: part,
                           to_map: part_associations,
                           additional_relation_data: { source_colony: 1, process: "resuspension" }
                         })

            # Associate additional data to this part
            part_associations.put('control', "positive_gfp")
            part_associations.save
            # Add control strain to collection
            # collection_sample_matrix = collection.matrix
            # collection_sample_matrix[r][c] = strain_sample_id
            # collection.matrix = collection_sample_matrix 
        end
        control_plate_associations.save
        
        need_to_create_new_control_plate = show do
            title "Checking Control Plate #{positive_gfp_control_plate}" 
            separator
            select ["Yes", "No"], var: "make_new_plate" , label: "Are there colonies left to be picked?" , default: 1
        end
        
        release [positive_gfp_control_plate], interactive: true
        return need_to_create_new_control_plate[:make_new_plate].to_s
    end
    
    
    # Finds where an alpha_coordinate is in a 96 Well plate
    #
    # @params alpha_coord [array or string] can be a single alpha_coordinate or a list of alpha_coordinate strings ie: 'A1' or ['A1','H7']
    # @return rc_list [Array] a list of [r,c] coordinates that describe where the alpha_coord(s) are in a 96 well matrix
    def find_rc_from_alpha_coord(alpha_coord)
        # look for where alpha coord is 2-D array coord
        coordinates_96 = ('A'..'H').to_a.map {|row| (1..12).to_a.map {|col| row + col.to_s}} 
        rc_list = []
        if alpha_coord.instance_of? Array
            # alpha_coord = alpha_coord.map {|a| a.upcase}
            alpha_coord.each {|a_coord|
                coordinates_96.map.each_with_index { |row, r_idx| row.each_index.select {|col| row[col] == a_coord.upcase}.each { |c_idx| rc_list.push([r_idx, c_idx]) } } 
            }
        else
            coordinates_96.map.each_with_index { |row, r_idx| row.each_index.select {|col| row[col] == alpha_coord.upcase}.each { |c_idx| rc_list.push([r_idx, c_idx]) } }
        end
        return rc_list
    end
    
    
    def diluting_gfp_control(in_collection, out_collection, final_od=0.0003)
        in_data_matrix = in_map.get_data_matrix
        
        in_data_matrix.each_with_index do |row, r_idx|
            row.each_with_index do |part_data, c_idx|
                if !part_data.nil?
                    if part_data['control'] == 'positive_gfp'
                        # record relation between input and output parts, well position is the same
                        # for this transfer
                        from_part = in_collection.part(r_idx, c_idx)
                        to_part = out_collection.part(r_idx, c_idx)
                        in_map = AssociationMap.new(from_part)
                        out_map = AssociationMap.new(to_part)
                        add_provenance({
                                         from: from_part,
                                         from_map: in_map,
                                         to: to_part,
                                         to_map: out_map,
                                         additional_relation_data: { process: "dilution" }
                                       })
            
                        # Associate additional data to this part on output collection
                        out_map.put('control', "positive_gfp")
                        out_map.put('od600', "#{final_od}")
                        in_map.save
                        out_map.save

                        # manually populate sample_id matrix of output collection
                        out_collection.matrix[r_idx][c_idx] = in_collection.matrix[r_idx][c_idx]
                        out_collection.save
                    end
                end
            end
        end
    end

    def sync_gfp_control(gfp_input_cult_coord, gfp_output_cult_coord, input_plate_ods, final_output_vol)
        gfp_input_cult_coord = find_rc_from_alpha_coord(alpha_coord=gfp_input_cult_coord)
        gfp_input_cult_od = gfp_input_cult_coord.map {|r,c| input_plate_ods[r][c]}.first * 10 #dilution 1:10
        gfp_input_cult_vol = ((0.0003*final_output_vol)/gfp_input_cult_od) * 1000 # converting to ul
        gfp_input_media_vol = (1000.0 - gfp_input_cult_vol).round(2)
        return gfp_input_cult_vol, gfp_input_media_vol
    end

    
end # Module
