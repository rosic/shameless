describe Shameless::Store do
  it 'works' do
    _, model = build_store
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)

    expect(instance.uuid).not_to be_nil
    expect(model.where(hotel_id: 1).first.uuid).to eq(instance.uuid)
  end

  it 'allows access to base fields' do
    _, model = build_store
    model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s)
    fetched = model.where(hotel_id: 1).first

    expect(fetched[:hotel_id]).to eq(1)
    expect(fetched[:room_type]).to eq('roh')
    expect(fetched[:check_in_date]).to eq(Date.today.to_s)
  end

  it 'stores non-index fields on the body' do
    _, model = build_store
    model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 90)
    fetched = model.where(hotel_id: 1).first

    expect(fetched[:net_rate]).to eq(90)
  end

  it 'properly loads base values when using where' do
    _, model = build_store
    instance = model.put(hotel_id: 1, room_type: 'roh', check_in_date: Date.today.to_s, net_rate: 90)

    fetched = model.where(hotel_id: 1).first
    expect(fetched.uuid).to eq(instance.uuid)
    expect(fetched.ref_key).to eq(0)
  end

  it 'names the model by downcasing the class name' do
    store, _ = build_store do |s|
      Store = s

      class MyModel
        Store.attach(self)

        index do
          integer :my_id
          shard_on :my_id
        end
      end
    end

    partition = nil
    store.each_partition {|p| partition ||= p }
    expect(partition.from('store_mymodel_000001').count).to eq(0)

    Object.send(:remove_const, :MyModel)
    Object.send(:remove_const, :Store)
  end

  it 'names the default index "primary"' do
    store, _ = build_store do |s|
      Store = s

      class MyModel
        Store.attach(self)

        index do
          integer :my_id
          shard_on :my_id
        end
      end
    end

    partition = nil
    store.each_partition {|p| partition ||= p }
    expect(partition.from('store_mymodel_primary_index_000001').count).to eq(0)

    Object.send(:remove_const, :MyModel)
    Object.send(:remove_const, :Store)
  end

  it 'allows naming the index' do
    store, _ = build_store do |s|
      Store = s

      class MyModel
        Store.attach(self)

        index :foo do
          integer :my_id
          shard_on :my_id
        end
      end
    end

    partition = nil
    store.each_partition {|p| partition ||= p }
    expect(partition.from('store_mymodel_foo_index_000001').count).to eq(0)

    Object.send(:remove_const, :MyModel)
    Object.send(:remove_const, :Store)
  end

  it 'passes connection options to Sequel' do
    expect(Sequel).to receive(:connect).with(anything, max_connections: 7).and_call_original
    build_store(connection_options: {max_connections: 7})
  end

  it 'passes database extensions to Sequel' do
    db = double(Sequel::SQLite::Database).as_null_object
    allow(Sequel).to receive(:connect).and_return(db)
    build_store(database_extensions: [:foo])

    expect(db).to have_received(:extension).with(:foo)
  end

  it 'passes create table options to create_table' do
    db = double(Sequel::SQLite::Database).as_null_object
    allow(Sequel).to receive(:connect).and_return(db)
    build_store(create_table_options: {temp: true})

    expect(db).to have_received(:create_table).with("store_rates_000000", temp: true)
  end

  describe '#padded_shard' do
    it 'returns a 6-digit shard number' do
      store, _ = build_store

      expect(store.padded_shard(1)).to eq('000001')
      expect(store.padded_shard(35)).to eq('000003')
    end
  end

  describe '#disconnect' do
    it 'disconnects from partitions but keeps instances' do
      store, _ = build_store

      partition = nil
      store.each_partition {|p| partition = p }

      store.disconnect

      store.each_partition {|p| expect(p).to eq(partition) }
    end
  end

  describe '#each_partition' do
    it 'yields all partitions and their table names' do
      store, _ = build_store(partitions_count: 2)
      table_names_by_partition = {}

      store.each_partition do |partition, table_names|
        table_names_by_partition[partition] = table_names
      end

      expect(table_names_by_partition.count).to eq(2)
      table_names_by_partition.keys.each do |partition|
        expect(partition).to be_an_instance_of(Sequel::SQLite::Database)
      end
      expect(table_names_by_partition.values.first).to eq(%w[store_rates_000000 store_rates_000001
        store_rates_primary_index_000000 store_rates_primary_index_000001])
      expect(table_names_by_partition.values.last).to eq(%w[store_rates_000002 store_rates_000003
        store_rates_primary_index_000002 store_rates_primary_index_000003])
    end
  end
end
